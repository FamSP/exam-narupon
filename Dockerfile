# ใช้ Official Python image เป็น base image
FROM python:3.13-slim

# กำหนด Working Directory ภายใน Container
WORKDIR /app

# Copy ไฟล์ requirements.txt เข้าไปก่อน เพื่อใช้ cache layer ของ Docker
COPY requirements.txt .

# ติดตั้ง Dependencies ที่ระบุไว้
RUN pip install --no-cache-dir -r requirements.txt

# Copy โค้ดทั้งหมดในโปรเจกต์เข้าไปใน container
COPY . .

# กำหนด Port ที่ Container จะทำงาน
EXPOSE 5000

# คำสั่งสำหรับรัน Flask Application
CMD ["python", "app.py"]