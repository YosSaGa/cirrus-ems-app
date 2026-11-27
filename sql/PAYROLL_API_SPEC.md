# Payroll & Deductions — Backend Migration & API Spec

เอกสารสำหรับทีม Backend (`NestJS` + `PostgreSQL` บน `https://api.cirrusmarine.site/api/v1/ems`) เพื่อเปิดใช้งานเมนู **Settings > Payroll & Deductions** และการหักยอดสุทธิในหน้า **Pay Estimate** ของแอปมือถือ (`lib/services/payroll_service.dart`)

---

## 1. SQL Migration

รันไฟล์ [`sql/001_employee_payroll_items.sql`](./001_employee_payroll_items.sql) บนฐานข้อมูล PostgreSQL:

- ใช้ตารางเดิมที่มีอยู่แล้ว: `core.employees`, `hr.compensation`, `hr.payroll_components`
- สร้างตารางใหม่ 1 ตาราง: **`hr.employee_payroll_items`** (ผูก `employee_id -> core.employees(id)` และ `component_id -> hr.payroll_components(id)`)
- Seed component มาตรฐาน 3 ตัวลง `hr.payroll_components` แบบ idempotent (`ACCOMMODATION`, `SOCIAL_SECURITY`, `WORK_INSURANCE`)

---

## 2. สิทธิ์การเข้าถึง (RBAC)

- **`GET /payroll/my-config`**: พนักงานทุกคนที่ล็อกอิน (อ่านข้อมูลของตัวเองจาก JWT)
- **Endpoint จัดการ (`/payroll/employees*`, `/payroll/items*`)**: เฉพาะ Role **`Admin`**, **`HR Officer`**, **`Accountant`**, **`Owner`** (หรือ permission `payroll.create` / `payroll.update` / `payroll.delete`)

---

## 3. Endpoints ทั้ง 6 เส้น (Base: `/api/v1/ems`)

### 3.1 `GET /payroll/my-config`
ดึงเรทค่าแรงและรายการหักของพนักงานที่ล็อกอินอยู่ (แอปจะ fallback เป็น `MyPayrollConfig.empty` หาก endpoint ยังไม่เปิด)

**Response `200 OK`:**
```json
{
  "employeeId": "uuid",
  "salary": 15000.0,
  "hourlyRate": 62.5,
  "canManagePayroll": true,
  "items": [
    {
      "id": "uuid",
      "code": "SOCIAL_SECURITY",
      "name": "Social Security (ค่าประกันสังคม)",
      "componentType": "deduction",
      "calcMode": "percent",
      "amount": 5.0,
      "maxCap": 750.0,
      "isActive": true,
      "notes": null
    }
  ]
}
```

### 3.2 `GET /payroll/employees`
ดึงรายชื่อพนักงานทั้งหมดพร้อมเรทและรายการหัก (สำหรับ HR / Admin)

**Response `200 OK`:**
```json
{
  "employees": [
    {
      "employeeId": "uuid",
      "name": "สมชาย ใจดี",
      "employeeCode": "260831",
      "department": "Engineering",
      "employmentType": "full_time",
      "employmentStatus": "active",
      "salary": 15000.0,
      "hourlyRate": 62.5,
      "items": []
    }
  ]
}
```

### 3.3 `PATCH /payroll/employees/:employeeId/rate`
อัปเดตเรทต่อชั่วโมง (`hr.compensation`) และ/หรือฐานเงินเดือน (`core.employees.salary`) โดยแอปจะส่งเฉพาะฟิลด์ที่ต้องการอัปเดต (ส่ง `null` เพื่อล้างค่าได้)

**Request Body:**
```json
{
  "hourlyRate": 65.0,
  "salary": 15600.0
}
```

**Response `200 OK`:** `{ "ok": true }` (หรือข้อมูลที่อัปเดต)

### 3.4 `POST /payroll/employees/:employeeId/items`
เพิ่มรายการหัก (หรือรายรับ) ให้พนักงาน

**Request Body:**
```json
{
  "code": "ACCOMMODATION",
  "name": "Accommodation (ค่าที่พัก)",
  "componentType": "deduction",
  "calcMode": "fixed",
  "amount": 1500.0,
  "maxCap": null,
  "notes": "หอพักพนักงาน"
}
```
- `componentType`: `"deduction"` | `"earning"`
- `calcMode`: `"fixed"` (บาท) | `"percent"` (% ของยอดรวมก่อนหัก โดยเพดานสูงสุดอยู่ที่ `maxCap` ถ้ามี)

**Response `201 Created`:** Object ของ `PayrollAdjustmentItem` (เหมือนใน `items[]` ของ `3.1`)

### 3.5 `PATCH /payroll/items/:itemId`
แก้ไขหรือเปิด/ปิดรายการหัก (แอปส่งเฉพาะฟิลด์ที่เปลี่ยนแปลง; หากต้องการล้าง `maxCap` จะส่ง `"maxCap": null`)

**Request Body (ตัวอย่าง):**
```json
{
  "amount": 1200.0,
  "isActive": true,
  "maxCap": null
}
```

**Response `200 OK`:** Object ของ `PayrollAdjustmentItem` ที่อัปเดตแล้ว

### 3.6 `DELETE /payroll/items/:itemId`
ลบรายการหักออกจาก `hr.employee_payroll_items`

**Response `200 OK` / `204 No Content`**
