# Interview Guide

คู่มือสรุป framework สำหรับใช้เตรียมสัมภาษณ์สาย Platform, DevOps, Cloud, SRE และงาน technical ที่ต้องคุยทั้งฝั่ง engineering และ business

## 1. Framework สำหรับแนะนำตัวเอง

ใช้โครง `Present -> Past -> Impact -> Why this role`

### โครงตอบ

1. Present
เล่าว่าตอนนี้ทำอะไร อยู่บทบาทไหน และเชี่ยวชาญด้านใด

2. Past
เลือกประสบการณ์สำคัญ 2-3 เรื่องที่เกี่ยวกับ role ที่สมัคร

3. Impact
สรุปผลลัพธ์ที่วัดได้ เช่น ลดเวลา deploy, เพิ่ม reliability, ลด blocker, ช่วยทีมทำงานแทนกันได้

4. Why this role
ปิดท้ายว่าทำไม role นี้ตรงกับสิ่งที่คุณอยากทำต่อ

### Template

```text
ตอนนี้ผมทำงานด้าน [current area] โดยรับผิดชอบเรื่อง [key responsibilities]
ก่อนหน้านี้ผมมีประสบการณ์ในด้าน [relevant experiences]
สิ่งที่ผมโฟกัสมาตลอดคือการทำให้ [team/system/business outcome] ดีขึ้น เช่น [measurable impact]
จึงสนใจ role นี้เพราะอยากใช้ประสบการณ์ด้าน [relevant strength] ไปช่วยให้ทีม [target outcome]
```

### หลักจำ

- พูดให้จบใน 60-90 วินาที
- อย่าเล่าเป็น timeline ยาว
- เน้นสิ่งที่ตรงกับ role มากกว่าประวัติทั้งหมด
- ต้องมี impact อย่างน้อย 1-2 จุด

## 2. Framework สำหรับตอบคำถามตอนสัมภาษณ์

ใช้ `STAR` เป็นแกนหลัก และเสริมด้วย `Clarify -> Structure -> Trade-off` สำหรับคำถามเชิงเทคนิค

### STAR

1. Situation
สถานการณ์หรือบริบทคืออะไร

2. Task
โจทย์หรือหน้าที่ของคุณคืออะไร

3. Action
คุณทำอะไรบ้าง และทำไมถึงเลือกแบบนั้น

4. Result
ผลลัพธ์คืออะไร วัดได้ไหม และได้บทเรียนอะไร

### เสริมสำหรับคำถามเชิงเทคนิค

1. Clarify
ถ้าโจทย์ยังไม่ชัด ให้ถามกลับก่อน เช่น scale, reliability, security, constraints

2. Structure
แบ่งคำตอบเป็นหัวข้อ เช่น architecture, operation, observability, cost, security

3. Trade-off
อธิบายเหตุผลที่เลือก approach นี้ และข้อเสียที่ยอมรับได้

### สูตรตอบสั้น

```text
ปัญหาคืออะไร -> ผมรับผิดชอบอะไร -> ผมตัดสินใจทำอะไร -> ผลที่เกิดขึ้นคืออะไร -> บทเรียนคืออะไร
```

### ตัวอย่างการ framing คำตอบ

- ถ้าถามเรื่อง leadership: เน้น unblock, prioritization, coordination, ownership
- ถ้าถามเรื่อง conflict: เน้น alignment, expectation, risk, decision making
- ถ้าถามเรื่อง technical decision: เน้น requirements, options, trade-offs, outcome
- ถ้าถามเรื่องงานนอกขอบเขต: framing เป็นการลด friction และเพิ่มผลลัพธ์ของทีม

### ข้อควรระวัง

- อย่าเล่าเป็น task list
- อย่าตอบแบบไม่มีผลลัพธ์
- อย่า claim ว่าทำคนเดียวทั้งหมด ถ้าเป็นงานทีม
- อย่าลง detail จนหลุดคำถาม

## 3. Framework สำหรับรับมือกับ Incident

ใช้ลำดับ `Detect -> Assess -> Communicate -> Mitigate -> Recover -> Learn`

### 1. Detect

- รับรู้ปัญหาให้เร็วจาก alert, dashboard, logs หรือ user report
- ตรวจว่ากระทบ production หรือไม่

### 2. Assess

- ประเมิน severity และ blast radius
- ระบุว่ากระทบระบบไหน ผู้ใช้กลุ่มใด และธุรกิจเสียหายระดับไหน
- ตัดสินใจว่าต้อง escalate หรือไม่

### 3. Communicate

- ตั้ง owner หรือ incident commander ให้ชัด
- แยกคน investigate ออกจากคนสื่อสาร
- อัปเดต stakeholder เป็นช่วงเวลาโดยใช้ facts ไม่ใช้การคาดเดา

### 4. Mitigate

- โฟกัสลดผลกระทบก่อน root cause ถ้ายังไม่ชัด
- ตัวอย่างเช่น rollback, failover, scale up, disable feature, manual workaround

### 5. Recover

- ตรวจว่าระบบกลับมาปกติจริง
- เช็ก health, backlog, queue, data consistency, downstream impact

### 6. Learn

- ทำ postmortem แบบไม่โทษคน
- ระบุ root cause, contributing factors, detection gaps, process gaps
- ออก action items พร้อม owner และ due date

### หลักคิดสำคัญเวลา incident

- Fix impact before perfect fix
- One clear owner during incident
- Communicate facts, not guesses
- Keep timeline and decisions
- Postmortem ต้องจบด้วย action ที่ทำได้จริง

### Template สำหรับเล่า incident ในสัมภาษณ์

```text
เหตุการณ์คืออะไรและกระทบใครบ้าง
ผมประเมิน severity และจัดการการสื่อสารอย่างไร
ผมลดผลกระทบระยะสั้นด้วยวิธีไหน
root cause คืออะไร
หลังเหตุการณ์ ผมป้องกันไม่ให้เกิดซ้ำอย่างไร
```

## 4. Cheat Sheet ใช้ก่อนเข้าสัมภาษณ์

### ก่อนสัมภาษณ์

- เตรียม self-introduction เวอร์ชัน 60 วินาที
- เตรียม success stories 3 เรื่องโดยใช้ STAR
- เตรียม incident story 1 เรื่อง
- เตรียมตัวเลข impact ที่ใช้พูดได้จริง
- เตรียมคำถามถามกลับเกี่ยวกับ role, team, ownership, on-call, success criteria

### ระหว่างสัมภาษณ์

- ฟังคำถามให้จบก่อนตอบ
- ถ้าโจทย์ไม่ชัด ให้ clarify ก่อน
- ตอบเป็นโครง ไม่กระโดดไปมา
- ถ้าเป็น technical discussion ให้พูด trade-off เสมอ
- ถ้าพลาดหรือจำไม่ได้ ให้บอกตรงๆ แล้วอธิบายวิธีคิดแทน

### หลังสัมภาษณ์

- จดว่าคำถามไหนตอบได้ดี
- จดช่องโหว่ที่ต้องเตรียมเพิ่ม
- อัปเดต impact stories ให้คมขึ้น

## 5. สรุปจำง่าย

- แนะนำตัว: `Present -> Past -> Impact -> Why this role`
- ตอบคำถาม: `STAR + Clarify + Structure + Trade-off`
- รับมือ incident: `Detect -> Assess -> Communicate -> Mitigate -> Recover -> Learn`