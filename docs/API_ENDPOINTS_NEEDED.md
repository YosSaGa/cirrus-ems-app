# แบบฟอร์มกรอกข้อมูล API 3 เส้นสุดท้ายจากฝั่งเว็บ (Cirrus EMS)

**Base URL:** `https://api.cirrusmarine.site/api/v1/ems`

> **วิธีส่งกลับ:** รบกวนเพื่อน **เติมข้อมูลลงในไฟล์ `.md` นี้เลย** (หรือสร้างเป็นไฟล์ `.md` ส่งกลับมา)  
> ดูได้จาก **F12 → แท็บ Network** บนหน้าเว็บตอนกดปุ่มทั้ง 3 ขั้นตอน (ก๊อป **Method + URL + Payload (Request Body)** และถ้ามี **Response** ส่งมาด้วยจะดีมากครับ)

---

## 1. เส้น Clock-In (ลงเวลาเข้างานประจำวัน) *สำคัญสุด*
> ตอนนี้แอปยิง `POST /work-sessions` แล้วเซิร์ฟเวอร์แจ้ง:  
> `"Team member ... needs an active employee attendance clock-in for today before checking in to a job"`  
> แสดงว่าต้องยิงเส้น Clock-In ของเว็บ (ตาราง `hr.attendance_records`) ก่อน

- **Method:** `(เช่น POST)`
- **URL:** `(เช่น /api/v1/ems/...)`
- **Request Body (JSON):**
  ```json
  {
    
  }
  ```
- **Response (ถ้ามี):**
  ```json
  {
    
  }
  ```

---

## 2. เส้น Check-Out / ปิดรอบ Work Session
> ตอนกดออกงาน / พักเบรก จาก `work-sessions`

- **Method:** `(เช่น PATCH หรือ POST)`
- **URL:** `(เช่น /api/v1/ems/work-sessions/:id หรือ /work-sessions/:id/...)`
- **Request Body (JSON):**
  ```json
  {
    
  }
  ```
- **Response (ถ้ามี):**
  ```json
  {
    
  }
  ```

---

## 3. เส้นส่งรายงานช่าง (`technician-reports`)
> ตอนกดบันทึกรายงานการทำงานหลังจบงาน (พร้อมแนบรูป + ปัญหาที่พบ)

- **Method:** `(เช่น POST)`
- **URL:** `(เช่น /api/v1/ems/technician-reports)`
- **Request Body (JSON):**
  ```json
  {
    
  }
  ```
- **Response (ถ้ามี):**
  ```json
  {
    
  }
  ```

---

*(กรอกเสร็จแล้วส่งไฟล์ `.md` กลับมาได้เลยครับ จะเอาไปเชื่อมให้ตรง DTO 100% ทีเดียวจบทั้ง Flow)*
