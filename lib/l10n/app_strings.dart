import '../services/language_service.dart';
import '../services/theme_service.dart';

/// Lightweight centralized EN/TH/MS display string resolver.
///
/// Default language is English ([AppLanguage.en]), preserving all existing
/// UI copy and test expectations. Switching to Thai ([AppLanguage.th]) or
/// Bahasa Melayu ([AppLanguage.ms]) only translates presentation strings —
/// never backend values, stored keys, or user-entered text.
class AppStrings {
  AppStrings._();

  static bool get isThai => LanguageService.isThai;
  static bool get isMalay => LanguageService.isMalay;

  /// Returns [th] when Thai is active, [ms] (or dictionary lookup) when Malay
  /// is active, otherwise [en].
  static String t(String en, String th, [String? ms]) {
    if (isThai) return th;
    if (isMalay) return ms ?? _msByEn[en] ?? en;
    return en;
  }

  static const _enMonths = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _thMonths = <String>[
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  static const _msMonths = <String>[
    'Januari',
    'Februari',
    'Mac',
    'April',
    'Mei',
    'Jun',
    'Julai',
    'Ogos',
    'September',
    'Oktober',
    'November',
    'Disember',
  ];

  static const _enMonthsShort = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _thMonthsShort = <String>[
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  static const _msMonthsShort = <String>[
    'Jan',
    'Feb',
    'Mac',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Ogo',
    'Sep',
    'Okt',
    'Nov',
    'Dis',
  ];

  static const _enWeekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _thWeekdays = <String>[
    'วันจันทร์',
    'วันอังคาร',
    'วันพุธ',
    'วันพฤหัสบดี',
    'วันศุกร์',
    'วันเสาร์',
    'วันอาทิตย์',
  ];

  static const _msWeekdays = <String>[
    'Isnin',
    'Selasa',
    'Rabu',
    'Khamis',
    'Jumaat',
    'Sabtu',
    'Ahad',
  ];

  static String monthName(int month) {
    final idx = (month - 1).clamp(0, 11);
    if (isThai) return _thMonths[idx];
    if (isMalay) return _msMonths[idx];
    return _enMonths[idx];
  }

  static String monthShort(int month) {
    final idx = (month - 1).clamp(0, 11);
    if (isThai) return _thMonthsShort[idx];
    if (isMalay) return _msMonthsShort[idx];
    return _enMonthsShort[idx];
  }

  static String weekdayName(int weekday) {
    final idx = (weekday - 1).clamp(0, 6);
    if (isThai) return _thWeekdays[idx];
    if (isMalay) return _msWeekdays[idx];
    return _enWeekdays[idx];
  }

  static String formatMonthYear(int year, int month) =>
      '${monthName(month)} $year';

  static String formatFullDate(DateTime date) {
    if (isThai) {
      return '${weekdayName(date.weekday)}ที่ ${date.day} ${monthName(date.month)} ${date.year}';
    }
    if (isMalay) {
      return '${weekdayName(date.weekday)}, ${date.day} ${monthName(date.month)} ${date.year}';
    }
    return '${weekdayName(date.weekday)}, ${monthName(date.month)} ${date.day}, ${date.year}';
  }

  static String formatShortDate(DateTime date) {
    if (isThai || isMalay) {
      return '${date.day} ${monthShort(date.month)} ${date.year}';
    }
    return '${monthShort(date.month)} ${date.day}, ${date.year}';
  }

  static String formatHoursMinutes(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (isThai) {
      return '$h ชม. $m น.';
    }
    if (isMalay) {
      return '${h}j ${m}m';
    }
    return '${h}h ${m}m';
  }

  static String themeTitle(AppThemeMode mode) {
    if (isThai) {
      switch (mode) {
        case AppThemeMode.defaultTheme:
          return 'Cirrus Signature (มาตรฐาน)';
        case AppThemeMode.white:
          return 'Pure White (สว่างคลีน)';
        case AppThemeMode.black:
          return 'Obsidian Black (โหมดมืด)';
      }
    }
    if (isMalay) {
      switch (mode) {
        case AppThemeMode.defaultTheme:
          return 'Cirrus Signature (Lalai)';
        case AppThemeMode.white:
          return 'Pure White (Minimalis Cerah)';
        case AppThemeMode.black:
          return 'Obsidian Black (Mod Gelap)';
      }
    }
    return mode.title;
  }

  static String themeDescription(AppThemeMode mode) {
    if (isThai) {
      switch (mode) {
        case AppThemeMode.defaultTheme:
          return 'กรมท่า 30% • ขาวนวล 60% • เขียวมิ้นต์ 10%';
        case AppThemeMode.white:
          return 'มินิมอลสีขาวสะอาดตาและสีเทาสเลท';
        case AppThemeMode.black:
          return 'โหมดมืด OLED ตัดด้วยสีเขียวมิ้นต์นีออน';
      }
    }
    if (isMalay) {
      switch (mode) {
        case AppThemeMode.defaultTheme:
          return 'Biru Laut 30% • Putih Lembut 60% • Teal 10%';
        case AppThemeMode.white:
          return 'Putih bersih minimalis & kelabu lembut';
        case AppThemeMode.black:
          return 'Mod gelap OLED dengan aksen teal neon';
      }
    }
    return mode.description;
  }

  /// Translates a leave type label for display without altering stored keys.
  static String leaveTypeLabel(String rawType) {
    final normalized = rawType.trim().toLowerCase();
    if (isThai) {
      switch (normalized) {
        case 'sick':
        case 'sick leave':
          return 'ลาป่วย';
        case 'personal':
        case 'personal leave':
          return 'ลากิจ';
        case 'annual':
        case 'annual leave':
          return 'ลาพักร้อน';
        case 'unpaid':
        case 'unpaid leave':
          return 'ลาไม่รับค่าจ้าง';
        case 'other':
        case 'other leave':
          return 'ลาอื่นๆ';
        default:
          return rawType;
      }
    }
    if (isMalay) {
      switch (normalized) {
        case 'sick':
        case 'sick leave':
          return 'Cuti Sakit';
        case 'personal':
        case 'personal leave':
          return 'Cuti Peribadi';
        case 'annual':
        case 'annual leave':
          return 'Cuti Tahunan';
        case 'unpaid':
        case 'unpaid leave':
          return 'Cuti Tanpa Gaji';
        case 'other':
        case 'other leave':
          return 'Cuti Lain';
        default:
          return rawType;
      }
    }
    return rawType;
  }

  /// Translates an attendance scan window / scan type label for display.
  static String scanWindowLabel(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (isThai) {
      switch (normalized) {
        case 'morning_in':
        case 'morning in':
        case 'check in':
          return 'เข้างานเช้า';
        case 'lunch_out':
        case 'lunch out':
          return 'พักเที่ยง';
        case 'afternoon_in':
        case 'afternoon in':
          return 'เข้างานบ่าย';
        case 'evening_out':
        case 'evening out':
        case 'check out':
        case 'leave':
          return 'เลิกงาน';
        default:
          return raw;
      }
    }
    if (isMalay) {
      switch (normalized) {
        case 'morning_in':
        case 'morning in':
        case 'check in':
          return 'Masuk Pagi';
        case 'lunch_out':
        case 'lunch out':
          return 'Keluar Rehat';
        case 'afternoon_in':
        case 'afternoon in':
          return 'Masuk Petang';
        case 'evening_out':
        case 'evening out':
        case 'check out':
        case 'leave':
          return 'Pulang';
        default:
          return raw;
      }
    }
    return raw;
  }

  /// Translates attendance scan source badge (e.g. APP / FINGERPRINT).
  static String scanSourceLabel(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (isThai) {
      switch (normalized) {
        case 'app':
          return 'แอป';
        case 'fingerprint':
          return 'สแกนนิ้ว';
        case 'web':
          return 'เว็บ';
        default:
          return raw;
      }
    }
    if (isMalay) {
      switch (normalized) {
        case 'app':
          return 'Aplikasi';
        case 'fingerprint':
          return 'Cap Jari';
        case 'web':
          return 'Web';
        default:
          return raw;
      }
    }
    return raw;
  }

  /// Centralized Bahasa Melayu translations for shared UI strings.
  static const Map<String, String> _msByEn = {
    // Bottom Nav & Main Tabs
    'Attendance': 'Kehadiran',
    'History': 'Sejarah',
    'Pay & Leave': 'Gaji & Cuti',
    'Profile': 'Profil',
    'Earnings & Leave': 'Pendapatan & Cuti',
    'Pay estimate': 'Anggaran Gaji',
    'Local leave': 'Cuti Tempatan',

    // Attendance Screen
    'Good morning': 'Selamat pagi',
    'Good afternoon': 'Selamat tengah hari',
    'Good evening': 'Selamat petang',
    'Check In': 'Daftar Masuk',
    'Check Out': 'Daftar Keluar',
    'Already recorded': 'Sudah direkodkan',
    "Today's Activity": 'Aktiviti Hari Ini',
    'No attendance recorded yet today.': 'Tiada rekod kehadiran hari ini.',
    'Open': 'Dibuka',
    'Pending': 'Menunggu',
    'Recorded': 'Direkod',
    'Closed': 'Ditutup',
    'Retry': 'Cuba Lagi',
    'Refresh': 'Muat Semula',
    'Bangkok Time': 'Masa Bangkok',

    // History Screen
    'Monthly Attendance Summary': 'Ringkasan Kehadiran Bulanan',
    'Monthly Scan History': 'Sejarah Imbasan Bulanan',
    'Hours Used for Pay': 'Jam Dikira Gaji',
    'Total Working Hours': 'Jumlah Jam Bekerja',
    'Recalculate': 'Kira Semula',
    'View all': 'Lihat Semua',
    'Show less': 'Tunjuk Sedikit',
    'Scan Event': 'Rekod Imbasan',
    'Present': 'Hadir',
    'Leave': 'Cuti',
    'Absent': 'Tidak Hadir',
    'Overtime': 'Kerja Lebih Masa',

    // Pay Estimate & Simulator
    'Previous month': 'Bulan sebelumnya',
    'Next month': 'Bulan seterusnya',
    'Estimated base pay': 'Anggaran gaji asas',
    'Period open · Running estimate': 'Tempoh dibuka · Anggaran semasa',
    'Period ended · Estimate only': 'Tempoh tamat · Anggaran sahaja',
    'Verified hours counted': 'Jam disahkan dikira',
    'Bonus time after 17:00': 'Masa bonus selepas 17:00',
    'Salary-based hourly rate': 'Kadar sejam berasaskan gaji',
    'Hourly wage rate': 'Kadar upah sejam',
    'Fixed daily wage estimate': 'Anggaran upah harian tetap',
    'Configured by HR / Admin / Accountant': 'Ditetapkan oleh HR / Admin / Akauntan',
    'How this is calculated': 'Cara pengiraan',
    'Deductions & Estimated Net Pay': 'Potongan & Anggaran Gaji Bersih',
    'Gross hourly pay': 'Gaji kasar mengikut jam',
    'Estimated Net Pay': 'Anggaran Gaji Bersih',
    'Pay Simulator': 'Simulator Gaji',
    'Test custom salary, base days & hours': 'Uji gaji, hari asas & jam bekerja',
    'Simulated Estimate': 'Anggaran Simulasi',
    'Hourly Rate': 'Kadar Sejam',
    'Daily Rate (8h)': 'Kadar Harian (8j)',
    'Monthly Salary (THB)': 'Gaji Bulanan (THB)',
    'Base days per month (÷ 8h/day standard)': 'Hari asas sebulan (÷ 8j/hari standard)',
    'Working time to simulate': 'Masa bekerja untuk simulasi',
    'Hours': 'Jam',
    'Minutes (0-59)': 'Minit (0-59)',
    'Reading scans…': 'Membaca imbasan…',
    'Estimate unavailable': 'Anggaran tidak tersedia',
    'EMPLOYEE': 'PEKERJA',
    'EMP CODE': 'KOD PEKERJA',
    'PERIOD': 'TEMPOH',

    // Local Leave & PDF
    'Save draft on this device': 'Simpan draf pada peranti ini',
    'View PDF': 'Lihat PDF',
    'Leave PDF': 'PDF Cuti',
    'Print PDF': 'Cetak PDF',
    'Download PDF': 'Muat Turun PDF',
    'Share PDF': 'Kongsi PDF',
    'Cancel this leave draft?': 'Batalkan draf cuti ini?',
    'Back': 'Kembali',
    'Cancel draft': 'Batalkan draf',
    'All Leave Drafts': 'Semua Draf Cuti',
    'All': 'Semua',
    'Active': 'Aktif',
    'Cancelled': 'Dibatalkan',
    'Saved on this device • not submitted to your manager':
        'Disimpan pada peranti • belum dihantar kepada pengurus',
    'You already have an active leave draft for these dates. Cancel it first or pick different dates.':
        'Anda sudah mempunyai draf cuti aktif untuk tarikh ini. Batalkan dahulu atau pilih tarikh lain.',

    // Profile & Settings
    'Settings': 'Tetapan',
    'Log Out': 'Log Keluar',
    'Signing out…': 'Sedang log keluar…',
    'Sign In': 'Log Masuk',
    'Signing in…': 'Sedang log masuk…',
    'PREFERENCES': 'KEUTAMAAN',
    'SYSTEM': 'SISTEM',
    'MANAGEMENT': 'PENGURUSAN',
    'ABOUT': 'TENTANG APLIKASI',
    'Appearance': 'Penampilan',
    'App Theme': 'Tema Aplikasi',
    'Pay Card Style': 'Gaya Kad Gaji',
    'SELECT CARD COLOR': 'PILIH WARNA KAD ANDA',
    'Tap the card above to flip and preview both sides.':
        'Ketik kad di atas untuk membalik dan melihat kedua-dua belah.',
    'Language': 'Bahasa',
    'DISPLAY LANGUAGE': 'BAHASA PAPARAN',
    'Choose your preferred app language.': 'Pilih bahasa paparan aplikasi anda.',
    'ACTIVE': 'AKTIF',
    'UPDATING': 'MENGEMAS KINI',
    'UPDATED': 'DIKEMAS KINI',
    'Payroll & Deductions': 'Gaji & Potongan',
    'Hourly rate, Accommodation, Social Security, Work Insurance':
        'Kadar sejam · Penginapan · Keselamatan Sosial · Insurans Kerja',
    'Save rate': 'Simpan kadar',
    'Add': 'Tambah',
    'Edit': 'Sunting',
    'Delete': 'Padam',
    'Cancel': 'Batal',
    'Save': 'Simpan',
    'Permission required': 'Kebenaran diperlukan',
  };
}
