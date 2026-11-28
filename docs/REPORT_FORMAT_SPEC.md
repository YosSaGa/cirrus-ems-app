# คู่มือจัดรูปแบบการแสดงผลรายงานช่าง (`workDescription`) บนหน้าเว็บ

> **ไม่กระทบ Backend และ Database 100%** — แอปมือถือส่งข้อมูลทั้งหมดผ่าน `POST /api/v1/ems/technician-reports` ในฟิลด์ `workDescription` ตัวเดิมอยู่แล้ว เอกสารนี้สำหรับปรับ **ฝั่งหน้าเว็บ (Frontend)** ตอนอ่านข้อมูลมาแสดงผลเป็นหัวข้อแยกกล่องให้อ่านง่ายขึ้น

---

## 1. โครงสร้างข้อความที่แอปมือถือส่งเข้า `workDescription`

แอปจะรวมข้อความเป็นบล็อก คั่นด้วย `\n\n` (2 บรรทัด) ตามลำดับนี้:

| ลำดับ | หัวข้อ (Marker) | เงื่อนไขการส่ง |
|---|---|---|
| 1 | **รายละเอียดงานที่ทำ (Summary)** | มีเสมอ (ข้อความส่วนบนก่อนจะเจอ `[...]` ตัวแรก) |
| 2 | `[ส่งรายงานช้า / Late Report: +<N> min (เกินกำหนด 07:00 น.)]` | มีเฉพาะกรณีช่างส่งรายงานช้าเกิน `07:00 น.` ของวันถัดไป (ค่า `N` คือจำนวนนาทีที่สาย) |
| 3 | `[ปัญหาที่พบ / Issues]\n<ข้อความ>` | มีเฉพาะกรณีช่างกรอกช่องปัญหาที่พบ/อะไหล่ที่ขาด |
| 4 | `[งานค้างต่อ / Recommendations]\n<ข้อความ>` | มีเฉพาะกรณีช่างกรอกช่องงานค้างต่อ/ข้อเสนอแนะ |

---

## 2. ตัวอย่าง JSON ที่แอปส่งจริง (`POST /technician-reports`)

```json
{
  "workSessionId": "550e8400-e29b-41d4-a716-446655440000",
  "workOrderId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "technicianId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "workType": "repair",
  "workDescription": "เปลี่ยนซีลปั๊มน้ำหล่อเย็นและทดสอบรันเครื่อง 30 นาที\n\n[ส่งรายงานช้า / Late Report: +25 min (เกินกำหนด 07:00 น.)]\n\n[ปัญหาที่พบ / Issues]\nน็อตยึดหน้าแปลนเป็นสนิม 1 ตัว ต้องตัดออก\n\n[งานค้างต่อ / Recommendations]\nรอเบิกน็อตสแตนเลส M10 รอบบ่าย",
  "photos": [
    "attendance/2026-11-28/photo-1.jpg",
    "attendance/2026-11-28/photo-2.jpg"
  ]
}
```

---

## 3. โค้ด TypeScript/JavaScript สำหรับแยกหัวข้อฝั่งเว็บ

รองรับทั้งรายงานใหม่จากแอป และรายงานเก่า/รายงานที่เขียนจากเว็บ (ไม่มี Marker จะคืน `summary` เต็มข้อความโดยไม่พัง):

```ts
export interface ParsedTechnicianReport {
  summary: string;
  issues: string | null;
  recommendations: string | null;
  lateMinutes: number | null;
}

export function parseTechnicianReportDescription(
  raw?: string | null,
): ParsedTechnicianReport {
  const text = (raw ?? '').trim();
  if (!text) {
    return { summary: '', issues: null, recommendations: null, lateMinutes: null };
  }

  let working = text;

  // 1. ดึงข้อมูลส่งรายงานช้า (ถ้ามี)
  let lateMinutes: number | null = null;
  const lateMatch = working.match(
    /\[ส่งรายงานช้า\s*\/\s*Late Report:\s*\+(\d+)\s*min[^\]]*\]/i,
  );
  if (lateMatch) {
    lateMinutes = Number.parseInt(lateMatch[1], 10);
    working = working.replace(lateMatch[0], '').trim();
  }

  // 2. แยกหัวข้อ [ปัญหาที่พบ / Issues] และ [งานค้างต่อ / Recommendations]
  const issuesMarker = '[ปัญหาที่พบ / Issues]';
  const recMarker = '[งานค้างต่อ / Recommendations]';

  const idxIssues = working.indexOf(issuesMarker);
  const idxRec = working.indexOf(recMarker);

  const firstMarkerIdx = [idxIssues, idxRec]
    .filter((i) => i >= 0)
    .sort((a, b) => a - b)[0];

  const summary =
    firstMarkerIdx !== undefined
      ? working.slice(0, firstMarkerIdx).trim()
      : working;

  let issues: string | null = null;
  if (idxIssues >= 0) {
    const start = idxIssues + issuesMarker.length;
    const end = idxRec > idxIssues ? idxRec : working.length;
    const val = working.slice(start, end).trim();
    if (val) issues = val;
  }

  let recommendations: string | null = null;
  if (idxRec >= 0) {
    const start = idxRec + recMarker.length;
    const end = idxIssues > idxRec ? idxIssues : working.length;
    const val = working.slice(start, end).trim();
    if (val) recommendations = val;
  }

  return { summary, issues, recommendations, lateMinutes };
}
```

---

## 4. แนวทางแสดงผลที่แนะนำบนหน้าเว็บ

1. **ส่วนบน (Header):** แสดง Tag `workType` (`SERVICE` / `REPAIR` / `MAINTENANCE`) และถ้า `lateMinutes !== null` ให้ติด Badge สีแดง **`ส่งรายงานช้า +${lateMinutes} นาที`**
2. **รายละเอียดงาน (Summary):** แสดงเป็นข้อความหลักพื้นปกติ
3. **ปัญหาที่พบ (`issues`):** ถ้าไม่เป็น `null` ให้แสดงในกล่องพื้นเหลืองอ่อน/ส้ม (`Warning`) พร้อมหัวข้อ **ปัญหาที่พบ**
4. **งานค้างต่อ (`recommendations`):** ถ้าไม่เป็น `null` ให้แสดงในกล่องพื้นฟ้าอ่อน (`Info`) พร้อมหัวข้อ **งานค้างต่อ / ข้อเสนอแนะ**
5. **รูปถ่าย (`photos`):** แสดง Thumbnail Grid คลิกขยายดูรูปเต็มได้
