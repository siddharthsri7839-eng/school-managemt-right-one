# School ERP Staff App - User Credentials & Authentication Guide

This document lists all default test accounts, demo roles, and authentication methods available in the **School ERP Staff App** (`school_erp_staff_app`).

---

## 1. Quick Access / One-Tap Demo Accounts

When the backend API server is set to Demo Mode, the login screen displays **Quick Access** one-tap buttons:

| Role | Username / Staff ID | Demo Login Trigger | Access Level |
| :--- | :--- | :--- | :--- |
| **School Administrator** | `schooladmin` / `admin@schoolerp.org` | One-Tap Button (`School Admin`) | Full administrative access (Staff HR, Leaves, Fees, Audit Trail, Exams, Notices) |
| **Teacher** | `teacher` / `teacher@schoolerp.org` | One-Tap Button (`Teacher`) | Academics, Timetable, Student Search, Take Attendance, Homework, Marks Entry |

---

## 2. Standard Login Credentials & Roles

| Role | Email / Staff ID | Default Password | Features & Permissions |
| :--- | :--- | :--- | :--- |
| **Administrator** | `admin@schoolerp.org` | `admin123` / `password` | System Admin, HR Staff Management, Staff Leave Approvals, Finance & Fees Reports, Audit Logs |
| **Senior Teacher** | `teacher@schoolerp.org` | `teacher123` / `password` | Attendance Marking, Student Search, Homework Management, Marks Entry, Classwork |
| **Accountant** | `accountant@schoolerp.org` | `accountant123` / `password` | Fee Dues, Financial Reports, Collection Analytics |
| **Librarian** | `librarian@schoolerp.org` | `librarian123` / `password` | Library Book Issue, Returns, Catalog Search |
| **Receptionist / Front Office** | `receptionist@schoolerp.org` | `receptionist123` | Gate Pass Scanner, Visitor Logs, Front Office Inquiries |
| **Driver / Transport** | `driver@schoolerp.org` | `driver123` | Transport Routes, Bus Tracking, Student Roster |

---

## 3. Local SQLite Demo Database Pre-Seeded Accounts

The local SQLite database (`school_erp_demo.db`) seeded for local testing includes the following staff profiles:

| ID | Name | Role | Department | Contact Email | Phone |
| :---: | :--- | :--- | :--- | :--- | :--- |
| **1** | Dr. Rajesh Verma | School Admin | Administration | `admin@schoolerp.org` | `+91 91234 56789` |
| **2** | Sunita Rao | Senior Teacher | Mathematics | `sunita.rao@schoolerp.org` | `+91 91234 56790` |
| **3** | Vikram Singh | Accountant | Finance | `finance@schoolerp.org` | `+91 91234 56791` |

---

## 4. Alternative Authentication Methods

### A. SMS / Email OTP Login (Passwordless)
1. Tap **LOGIN WITH SMS/OTP** on the login screen.
2. Enter registered phone number or email (e.g., `+91 91234 56789` or `admin@schoolerp.org`).
3. Enter test OTP: `123456` (or code received via SMS/Email).

### B. Biometric Authentication
* If supported by the device (Fingerprint / Face ID), enable **Biometric Login** under App Drawer -> Security Settings.
* Future logins can be authenticated instantly via device biometric scan.

---

## 5. API Server Endpoints

* **Production / Staging API Base URL**: `https://multischoolv2.projectworlds.com/api/v1/`
* **Demo Configuration Endpoint**: `/demo/config`
* **Demo Login Endpoint**: `/demo/login`
* **Standard Login Endpoint**: `/login`
The image you shared is the Web Admin Portal (Super Admin Web Dashboard) of the School ERP system.

Here is the exact difference between what is in your screenshot and what is in this project folder:

1. The Screenshot = Web Admin Portal 🌐
Target Users: School Owners, Principals, Super Admins, Accountants, and HR Managers.
Interface: Designed specifically for desktop screens with a full sidebar (Accounts, Finance, Lead Management, Front Office, Biometric Devices, School Website, etc.).
Purpose: High-level school management, financial tracking, system configuration, and overall reporting.
2. This Project Folder = Staff Mobile App 📱 (school_erp_staff_app)
Target Users: Teachers, Subject Teachers, and Staff Members.
Interface: Optimized for mobile phones (iOS & Android) and staff web view.
Purpose: Quick daily operations for staff:
📋 Taking class attendance
📚 Marking homework & classwork
🗓️ Viewing personal timetable
📝 Entering exam marks
💬 Staff chat & Notices
🔍 Scanning student QR codes
3. How They Connect Together 🔄
Even though the Web Admin Dashboard (screenshot) and this Staff Mobile App look different, they are fully connected to the same central database/API:

When a teacher takes attendance in this Staff Mobile App 📱 ➔ it instantly updates the "Attendance" and "Students Present" cards on the Web Admin Dashboard 🌐 (shown in your screenshot).
When an Admin changes fees or publishes notices on the Web Admin Portal 🌐 ➔ it immediately appears on the Staff Mobile App 📱.
Summary
Does this exact screen belong to the Web Section? Yes. That layout is the Web Admin Dashboard for desktop browsers.
Is this project connected to it? Yes. This Flutter app is the companion Staff Mobile Application that connects to the exact same backend API as that web dashboard.
8:50 AM
