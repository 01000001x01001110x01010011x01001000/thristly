# 🧃 Thristly — Stay Hydrated, Stay Healthy  

> **A smart Flutter hydration reminder app** that delivers **precise notifications** at custom intervals — even when the app is closed or your phone is asleep.  
> Powered by native Android **AlarmManager** for *exact* timing. 💧  

---

## 🌟 Overview  

**Thristly** helps you build a consistent hydration habit.  
Unlike typical reminder apps that miss alerts when the phone is idle, Thristly uses **native Kotlin code** and Flutter integration to trigger **exact-time notifications** — every time.  

You can customize:
- The **interval** between reminders (e.g., every 20, 30, or 60 minutes)  
- The **time range** (start and end hours of your day)  
- The **notification title** and **message**  

Once started, the app runs automatically — no need to restart it every day.

---

## ✨ Features  

✅ Schedule exact reminders (using `AlarmManager.setExactAndAllowWhileIdle()`)  
✅ Runs reliably in **background**, **sleep**, and **killed** states  
✅ Works automatically after **device reboot**  
✅ Customizable message, interval, and daily time range  
✅ Built with **Flutter + Kotlin Native Integration**  
✅ Battery optimization & exact alarm permission handling  
✅ Modern Material 3 interface  

---

## 📱 Screenshots  

| Home | Notification | Permissions |
|:----:|:-------------:|:------------:|
| ![Home Screen](docs/screenshot_home.png) | ![Notification](docs/screenshot_notify.png) | ![Permission](docs/screenshot_permission.png) |

*(Add your actual screenshots to `/docs/` folder later)*  

---

## ⚙️ Tech Stack  

| Layer | Technology |
|-------|-------------|
| UI | Flutter (Material 3) |
| State | StatefulWidget + Dart Controllers |
| Native | Kotlin (AlarmManager, BootReceiver, NotificationChannel) |
| Notifications | flutter_local_notifications + Android native |
| Data | SharedPreferences |
| Platforms | Android, iOS (basic support) |

---

## 🧩 Permissions  

| Permission | Why it’s needed |
|-------------|----------------|
| `POST_NOTIFICATIONS` | To display reminders |
| `USE_EXACT_ALARM` | To ensure precise alarm scheduling |
| `RECEIVE_BOOT_COMPLETED` | To reschedule after reboot |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | To keep reminders reliable in Doze mode |

> ⚠️ On Android 13+ and 14+, users must manually allow *Exact Alarms* in system settings.  
Thristly automatically navigates to the correct screen for you.

---

## 🚀 Getting Started  

### 1️⃣ Clone the repo  
```bash
git clone https://github.com/01000001x01001110x01010011x01001000/thristly.git
cd thristly
