"""
Configuration file for pytest
"""
import pytest
import sys
import os

# เพิ่ม parent directory ลงใน Python path เพื่อให้ import app ได้
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))