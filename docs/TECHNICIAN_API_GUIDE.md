# คู่มือการเชื่อมข้อมูล Job Code ระหว่างเว็บ ↔ แอปช่าง (Cirrus EMS)

**Base API URL:** `https://api.cirrusmarine.site/api/v1/ems`

---

## 1. สิ่งที่แอปมือถือเชื่อมต่ออยู่ตอนนี้

แอปฝั่งช่าง (Role `Technician` / `Admin`) เชื่อมตรงเข้ากับ API เดียวกับฝั่งเว็บแล้ว และ **รีเฟรชอัตโนมัติทุก 15 วินาที** เมื่อมี Job Code ใหม่เข้ามา:

| ฟังก์ชันในแอป | Endpoint ที่เรียกอยู่ตอนนี้ |
|---|---|
| ดึงรายการ Job Code ทั้งหมด | `GET /work-orders` + `GET /work-assignments` |
| ดึงรายละเอียดงานเต็ม | `GET /work-orders/:id` |
| กด Check-In เริ่มงาน | `POST /work-sessions` + `POST /app-attendance/events` |
| กด Break พัก / Check-Out จบงาน | `PATCH /work-sessions/:id` + `POST /app-attendance/events` |
| ส่งรายงานการทำงาน (+ รูปถ่าย + ปัญหาที่พบ) | `POST /technician-reports` (อัปโหลดรูปผ่าน `POST /storage/uploads`) |
| ดูประวัติงานและรายงานย้อนหลัง | `GET /work-sessions` + `GET /technician-reports` |

---

## 2. สิ่งที่ตอนนี้ขึ้นแล้ว vs ยังไม่ขึ้น

- **ขึ้นแล้ว:** รหัสงาน (`number` เช่น `WO-000014`), ชื่องาน (`title`), สถานะ (`status`), กำหนดการ (`scheduleStart → scheduleEnd`), ความสำคัญ (`priority`), รายละเอียด (`description` / `notes`)
- **ขึ้นแล้ว (อัปเดต 26 พ.ย. 2026):** ช่าง **ผู้รับผิดชอบ** อ่านจาก array **`technicians: [{ id, name }]`** ที่ `GET /work-orders` ส่งมา
  - แอปจับคู่ช่างกับบัญชีที่ล็อกอินจาก **`technicians[].id` = `core.users.id`** (และ fallback เทียบ username / ชื่อ เช่น `Bom V.2` แบบไม่สนตัวพิมพ์เล็ก/ใหญ่)
  - งานที่จับคู่ได้จะปักหมุดเป็น **`YOUR JOB`** และปลดล็อกปุ่ม Check In; ช่องผู้รับผิดชอบแสดงชื่อช่างทุกคนในงาน เช่น `M, Bom V.2`
- **หมายเหตุ:** `GET /work-assignments` ตอนนี้คืนรายการว่าง (`0` รายการ) แอปจึงใช้ `technicians` ใน work order เป็นแหล่งหลัก

---

## 3. สิ่งที่รบกวนขอจากฝั่งเว็บ (ไม่ต้องแก้ Backend)

เนื่องจากฝั่งเว็บก็เรียก API เดียวกันอยู่แล้ว รบกวนเปิด **F12 → แท็บ Network** บนหน้าเว็บตอนเปิดดูหรือสร้างงาน `WO-000014` แล้วส่ง **2 อย่างนี้** กลับมาให้หน่อยครับ:

### 3.1 ชื่อ URL (Path) ที่เว็บใช้ดึงรายชื่อช่าง/พนักงาน
- ตัวอย่าง: `GET /api/v1/ems/...` (เส้นที่คืนรายชื่อผู้ใช้มี `id` และ `name`)
- เพื่อให้ฝั่งแอปเอา `assignedTo` / `userId` (UUID) ไปแปลงเป็นชื่อช่างแสดงในช่อง `Assigned Technician` ได้เอง

### 3.2 ตัวอย่าง JSON 1 ก้อน จาก `GET /work-orders` และ `GET /work-assignments`
- ก๊อป Response ของงานตัวอย่าง (เช่น `WO-000014`) ส่งมาให้ดูชื่อฟิลด์จริง เช่น:
  - ฟิลด์ที่เก็บช่างที่ได้รับมอบหมาย (`assignedTo` / `assigned_to` / `assignments` / `userId` ฯลฯ)
  - ฟิลด์ที่เก็บ `description` และ `priority`

> เมื่อได้ 2 อย่างนี้แล้ว ฝั่งแอปจะแก้ตัว map ให้ตรง 100% ทันที **โดยไม่ต้องแก้โค้ดฝั่งเว็บหรือฝั่ง Backend เลยครับ**

---

## 4. (เพิ่มเติม) กรณีจะส่งให้ทีม Backend ปรับปรุงเพิ่มเติมในอนาคต

หากทีม Backend สามารถเพิ่มฟิลด์ใน `GET /work-orders` และ `GET /work-orders/:id` ได้ แค่ `LEFT JOIN core.users` แล้วส่งฟิลด์นี้เพิ่ม แอปจะรองรับอัตโนมัติทันที:

```json
{
  "id": "uuid",
  "number": "WO-000014",
  "title": "ชื่องาน",
  "description": "รายละเอียดงาน",
  "priority": "high",
  "status": "in_progress",
  "scheduleStart": "2026-11-28",
  "scheduleEnd": "2026-11-30",
  "assignedTo": "uuid-ของช่างใน-core.users",
  "assignedToName": "ชื่อช่างจาก-core.users.name"
}
```
