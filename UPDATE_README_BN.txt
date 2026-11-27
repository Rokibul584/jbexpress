UPAZILA EXPRESS — Area Charge Admin + Customer Order Tracking

এই ZIP-এ:
1) Admin Panel > এলাকার চার্জ সেটিংস-এ config.js-এর AREAS থেকে দ্রুত এলাকা নির্বাচন করা যাবে।
2) প্রতিটি এলাকার চার্জ Admin সংরক্ষণ/পরিবর্তন/বন্ধ করতে পারবেন। এলাকার নাম Customer Cart-এর এলাকার নামের সঙ্গে হুবহু মিলতে হবে।
3) Customer Home Page-এ ফোন নম্বর দিয়ে নিজের অর্ডারের অবস্থা দেখার Tracking Panel যোগ হয়েছে।
4) Tracking RPC কেবল Order Ref, Status, Date, Area এবং Amount দেখায়; ঠিকানা/নোট/Customer নাম/Rider ফোন প্রকাশ করে না।

Deployment:
- ZIP Extract করে এর ভেতরের ফাইলগুলো GitHub Repository root-এ upload/replace করুন।
- Supabase SQL Editor-এ delivery_charge_migration.sql সম্পূর্ণ Run করুন। এটি আগের delivery charge setup-এর সঙ্গে tracking function যোগ করে।
- Admin Panel-এ লগইন করে “এলাকার চার্জ সেটিংস” খুলুন। Quick area button চাপুন, Rider Charge লিখুন, সংরক্ষণ করুন।
- Customer Site-এ Ctrl+F5 দিয়ে refresh করে ফোন নম্বর দিয়ে Tracking পরীক্ষা করুন।

সীমাবদ্ধতা/নিরাপত্তা:
- ফোন নম্বর-ভিত্তিক Tracking-এ কেবল সীমিত অর্ডার তথ্য দেখানো হয়। Phone-only verification OTP নয়; বেশি নিরাপত্তার জন্য ভবিষ্যতে SMS OTP বা Order Ref + phone verification যুক্ত করা উচিত।
- Live Supabase-এ SQL Run ও বাস্তব অর্ডার দিয়ে পরীক্ষা না করা পর্যন্ত Live verified বলা যাবে না।
