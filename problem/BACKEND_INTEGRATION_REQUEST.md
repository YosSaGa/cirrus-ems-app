# สรุปปัญหาและวิธีแก้ฝั่ง Backend (`api.cirrusmarine.site`)

เอกสารนี้สรุปจุดที่แอปมือถือช่าง (**Cirrus EMS Flutter App**) เชื่อมต่อกับ Backend จริง `https://api.cirrusmarine.site/api/v1/ems` แล้วติดอยู่ เพื่อให้ฝั่ง Backend ช่วยปลดล็อกและยืนยันรูปแบบข้อมูลที่ถูกต้อง (แนบ Log การยิงจริงไว้ใน [backend_api_error.log](backend_api_error.log) และท้ายเอกสารนี้)

> **หมายเหตุ:** ไม่ต้องสร้างตารางใหม่หรือ Migrate Database (ใช้ตารางเดิมที่มีอยู่ใน `cirrus_02` ทั้งหมด)

**ภาพรวมการทำงานในแอป:** ช่างถ่ายรูปตอกบัตรเข้างาน → เลือกใบงาน (`Job Code`) → กดเริ่มงาน (`Check In`) → กดพักเบรก / เลิกงาน (`Break` / `End Shift`) → เขียนรายงานการทำงานพร้อมแนบรูปถ่าย (สูงสุด 4 รูป)

---

## ตารางสรุปภาพรวม

| หัวข้อ | สถานะ | ภาพรวมปัญหา | จุดที่ติด / สิ่งที่ต้องการ |
|---|---|---|---|
| 1. กดเริ่มใบงาน | ❌ ติดด่าน Clock-In | ช่างตอกบัตรเข้างานผ่านแอปแล้ว แต่ระบบยังมองว่าไม่ได้เข้างาน | `POST /work-sessions` เช็กเฉพาะ `hr.attendance_records` ไม่ได้เช็ก `hr.device_scans` |
| 2. พักเบรก / เลิกงาน | ⚠️ รอยืนยัน DTO | กดพักเที่ยงหรือเลิกงานเพื่อปิดรอบและหยุดจับเวลายังส่งไม่ถูก | ขอ Method + URL + ฟิลด์ที่อนุญาต (`forbidNonWhitelisted: true`) |
| 3. ส่งรายงานช่าง | ✅ DTO ผ่านแล้ว (รอแนบรูปจริง) | ทดสอบยิงจริงแล้ว DTO ผ่านหมด ติดแค่ต้อง Check-Out ก่อน | ยืนยันรูปแบบ `photos` เมื่อส่ง `storageKey` จริง (`string[]` หรือ object) |

---

## สิ่งที่แอปเชื่อมต่อกับ `api.cirrusmarine.site` ผ่านแล้ว 100%

- [x] **ดึงข้อมูลใบงานและรายละเอียดหน้างาน:** `GET /work-orders`, `GET /work-orders/:id`, `GET /work-assignments`, `GET /vessels`, `GET /projects`, `GET /assets`, `GET /team-members`
- [x] **ดึงประวัติรอบงานและรายงานย้อนหลัง:** `GET /work-sessions`, `GET /technician-reports`
- [x] **อัปโหลดรูปถ่าย (ทั้งรูปตอกบัตรและรูปหน้างาน):** `POST /storage/uploads` (ส่ง `uploadRequestId` เป็น UUID v4 และได้ `storageKey` กลับมาใช้งานต่อได้แล้ว)
- [x] **บันทึกตอกบัตรเข้างานจากแอปมือถือ:** `POST /app-attendance/events` (บันทึกลงตาราง `hr.device_scans` ผ่าน 100% — หน้าจอแอปขึ้น `MORNING IN ✓ RECORDED` แล้ว)

---

## ปัญหา

### 1. ช่างตอกบัตรเข้างานจากแอปแล้ว แต่ระบบไม่ยอมให้กดเริ่มใบงาน (`POST /work-sessions`)

ช่างเปิดแอปถ่ายรูปตอกบัตรเข้างานตอนเช้าเรียบร้อยแล้ว (ในแอปขึ้นบันทึกสำเร็จ `MORNING IN ✓ RECORDED`) แต่พอเลือกใบงานแล้วกดปุ่ม `CHECK IN` เพื่อเริ่มซ่อมเรือ ระบบกลับเด้งแจ้งว่ายังไม่ได้ตอกบัตรเข้างาน สาเหตุเพราะฝั่ง Backend ไปเปิดเช็กชื่อเฉพาะในสมุดลงเวลาของฝั่งเว็บ (`hr.attendance_records`) โดยไม่ได้นับรวมการตอกบัตรที่แอปส่งเข้ามาใน `hr.device_scans`

- แอปยิง `POST /app-attendance/events` สำเร็จ (`hr.device_scans`) แล้วจึงยิง `POST /work-sessions`
- ข้อมูลที่แอปส่งเข้า `POST /work-sessions` ปัจจุบัน (คัดเฉพาะฟิลด์ที่ DTO อนุญาตแล้ว หลังทดสอบเจอ `forbidNonWhitelisted` ตีกลับ `checkInAt`, `checkInLatitude`, `checkInLongitude`):
  ```json
  {
    "workOrderId": "<uuid>",
    "teamMemberId": "1becbc4e-3577-4c25-994d-65be2f6ad328",
    "createdBy": "1becbc4e-3577-4c25-994d-65be2f6ad328",
    "notes": "GPS: 13.756300, 100.501800"
  }
  ```
- เซิร์ฟเวอร์ตอบกลับ `400 Bad Request`:
  ```text
  Team member 1becbc4e-3577-4c25-994d-65be2f6ad328 needs an active employee attendance clock-in for today before checking in to a job -- clock in (or clock in again if already clocked out) first
  ```

### 2. ยังไม่รู้กติกาการส่งข้อมูลตอนกด "พักเบรก" หรือ "เลิกงาน" (`work-sessions`)

ตอนช่างกดพักเที่ยงหรือกดเลิกงาน แอปต้องส่งคำสั่งไปบอก Backend เพื่อปิดรอบงานและหยุดจับเวลา แต่เพราะ Backend ตั้งค่าตรวจสอบข้อมูลแบบเข้มงวด (`forbidNonWhitelisted: true`) ถ้าแอปส่งชื่อช่องข้อมูลผิดหรือเกินมาแม้แต่ช่องเดียว เซิร์ฟเวอร์จะปฏิเสธทั้งก้อนทันที จึงต้องรอชื่อช่องที่ถูกต้องจากฝั่ง Backend

- ยังไม่ทราบ **Method + URL** และรายชื่อฟิลด์ที่อนุญาตใน DTO สำหรับปิดรอบงาน (ทั้งกรณีพักเบรกและกรณีเลิกงาน/จบงาน)
- *หมายเหตุ Database:* คอลัมน์ `duration_minutes` ใน `hr.work_sessions` เป็น `GENERATED ALWAYS` ห้ามสั่ง `UPDATE` ตรงใน SQL

### 3. การส่งรายงานการทำงาน (`POST /technician-reports`) — DTO ผ่านแล้ว เหลือยืนยันรูปแบบ `photos`

หลังทดลองยิงเข้า `POST /technician-reports` จริง (ตัด `projectId` ที่ไม่รับออกแล้ว) DTO Validation ผ่านเรียบร้อย และเซิร์ฟเวอร์ตอบกลับ Business Rule ว่า `"You must check out of the job before creating a technician report."` — ตอนนี้แอปอัปโหลดรูปขึ้น `POST /storage/uploads` จนได้ `storageKey` แล้ว เหลือเพียงยืนยันว่าตอนมีรูปแนบ `photos` รับเป็นรูปแบบใด

---

## วิธีแก้

### 1. ปลดล็อกให้ช่างที่ตอกบัตรจากแอปมือถือแล้ว กดเริ่มใบงานได้ *(เลือกทำ 1 วิธี)*

- **วิธี A (แนะนำ — แก้จุดเดียวจบ):** ให้ระบบเช็กชื่อก่อนเริ่มงานใน `WorkSessionsService` ยอมรับทั้งคนที่ตอกบัตรจากฝั่งเว็บและฝั่งแอป โดยถือว่ามี Active Clock-In เมื่อพบการลงเวลาวันนี้ใน **`hr.attendance_records` หรือ `hr.device_scans`** *(หรืออีกทางคือให้ `POST /app-attendance/events` ช่วยลงแถวเข้างานใน `hr.attendance_records` ควบคู่ให้อัตโนมัติ)*
- **วิธี B (กรณีไม่ต้องการแก้ Logic ใน `WorkSessionsService`):** ส่ง **Method + URL + JSON Body** ของปุ่มลงเวลาเข้างานประจำวันฝั่งเว็บ (`hr.attendance_records`) มาให้แอป เพื่อเวลาช่างกดเริ่มงาน แอปจะได้ยิงตอกบัตรเข้าฝั่งเว็บนำร่องไปให้ก่อนเรียก `POST /work-sessions`

### 2. ส่งสเปก Endpoint & DTO สำหรับ "พักเบรก / เลิกงาน"

- ขอ **Method + URL** (เช่น `PATCH /work-sessions/:id` หรือ `POST /work-sessions/:id/check-out`)
- ขอ **รายชื่อฟิลด์ทั้งหมดที่ DTO อนุญาต** (เช่น `status`, `checkOutAt`, `jobStatusAtCheckout`, `notes`) พร้อมตัวอย่าง JSON Body 1 ชุดสำหรับพักเบรก และ 1 ชุดสำหรับเลิกงาน

### 3. ยืนยันรูปแบบฟิลด์ `photos` ของ `POST /technician-reports`

- ตอนนี้ `workOrderId`, `technicianId`, `workDescription`, `workType`, `findings`, `recommendations`, `status` ผ่านแล้ว
- ขอช่วยยืนยันเฉพาะรูปแบบของ **`photos`** เมื่อแนบรูปจริงจาก `POST /storage/uploads`:
  - แบบ `string[]`: `["storageKey1", "storageKey2"]`
  - หรือแบบ object array: `[{ "storageKey": "...", "caption": "..." }]` / `[{ "url": "...", "caption": "..." }]`

---

## ตารางอ้างอิง Database (ใช้ตารางเดิมใน `cirrus_02` ทั้งหมด)

| ตาราง | หน้าที่ในระบบ | หมายเหตุ |
|---|---|---|
| `hr.device_scans` | สมุดลงเวลาจากการสแกน/ถ่ายรูปผ่านแอปมือถือ | `POST /app-attendance/events` เขียนลงตารางนี้ผ่านแล้ว |
| `hr.attendance_records` | สมุดลงเวลาประจำวันฝั่งเว็บ | `WorkSessionsService` ใช้เช็ก Active Clock-In ของวันนี้ |
| `hr.work_sessions` | บันทึกเวลาเริ่มงาน-พักเบรก-เลิกงานของแต่ละใบงาน | `duration_minutes` เป็น `GENERATED ALWAYS` ห้าม `UPDATE` ตรง |
| `operations.technician_reports` | รายงานการทำงานและรูปหน้างานของช่างหลังจบงาน | ผูกกับ `work_orders` / `work_sessions` และรับไฟล์จาก `POST /storage/uploads` |

---

## Log การยิง API จริง (อ้างอิงจาก `problem/backend_api_error.log`)

```text
Base URL : https://api.cirrusmarine.site/api/v1/ems
User     : อานุวัฒน์ (Bom V.2) | UUID: 1becbc4e-3577-4c25-994d-65be2f6ad328
WorkOrder: WO-000016 (67SKIBIDI / WIND OF CHANGE)
Date     : 2026-11-26 (GMT+7)

[1] POST /storage/uploads -> 200/201 OK (ได้ storageKey สำเร็จ)
[2] POST /app-attendance/events (14:30:36) -> 200/201 OK (ลง hr.device_scans สำเร็จ)
[3] POST /work-sessions (15:44:07) -> 400 Bad Request
    Body : { "workOrderId": "<WO-000016-uuid>", "teamMemberId": "1becbc4e-3577-4c25-994d-65be2f6ad328", "createdBy": "1becbc4e-3577-4c25-994d-65be2f6ad328", "notes": "GPS: <lat>, <lng>" }
    Error: "Team member 1becbc4e-3577-4c25-994d-65be2f6ad328 needs an active employee attendance clock-in for today before checking in to a job -- clock in (or clock in again if already clocked out) first"
[4] POST /technician-reports (15:10) -> 400 Bad Request (DTO ผ่านแล้ว ติด Business Rule)
    Body : { "workOrderId": "<WO-000016-uuid>", "technicianId": "1becbc4e-3577-4c25-994d-65be2f6ad328", "workDescription": "...", "workType": "service", "photos": [], "status": "submitted" }
    Error: "You must check out of the job before creating a technician report."
```
