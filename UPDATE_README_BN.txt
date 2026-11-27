UPAZILA EXPRESS — Customer Panel + Area-based Rider Charge Update

এই ZIP-এ আপডেট করা হয়েছে:
1) index.html — Customer checkout-এ এলাকা নির্বাচন, Rider Charge, Product Subtotal ও Grand Total।
2) store.html — Store page-এর Customer Home / Cart navigation পরিষ্কার করা এবং malformed closing markup ঠিক করা। Store থেকে Provider Panel-এ redirect যোগ করা হয়নি।
3) admin.html — Admin > Delivery Charge থেকে এলাকার চার্জ Add / Edit / Delete / Active-Inactive করা যায়। Order list-এ Product, Rider Charge ও Grand Total আলাদা দেখায়।
4) delivery_charge_migration.sql — Supabase-এ area_delivery_charges table, RLS policies, customer_orders.delivery_charge / grand_total এবং server-side trigger যোগ করে।

প্রয়োজনীয় ইনস্টল ধাপ:
1) Supabase Dashboard > SQL Editor খুলুন।
2) delivery_charge_migration.sql-এর সম্পূর্ণ SQL Run করুন।
3) Run সফল হলে Admin Panel-এ Login করুন।
4) Admin > Delivery Charge-এ গিয়ে প্রতিটি এলাকার প্রকৃত Rider Charge যোগ করুন। উদাহরণ হিসেবে জীবননগর বাজার, উথলী, হাসাদাহ, বাঁকা ইত্যাদি এলাকার নাম যোগ করুন। টাকা নিজেরা নির্ধারণ করবেন; ZIP-এ কোনো কাল্পনিক চার্জ বসানো হয়নি।
5) এরপর ZIP-এর সব ফাইল Hosting-এ আপলোড করুন (config.js আগের মতো একই Supabase project-এ থাকবে)।
6) Browser cache clear করে Customer Home > Store > Cart > Checkout পরীক্ষা করুন।

গুরুত্বপূর্ণ সামঞ্জস্য নোট:
- Existing create_customer_order RPC-এর argument list পরিবর্তন করা হয়নি। Customer note-এ fee marker পাঠানো হয় এবং Database trigger customer_orders.area থেকে server-side fee হিসাব করে delivery_charge / grand_total সংরক্ষণ করে।
- কোনো এলাকার Active charge সেট না থাকলে Database order reject করবে; এতে ভুল বা শূন্য Rider Charge-এ অর্ডার নেওয়া হবে না।
- পুরোনো order-এর delivery_charge 0 রাখা হয়েছে; পুরোনো অর্ডারের জন্য অতীতের চার্জ অনুমান করা হয়নি।
- Existing provider/rider/auth code ইচ্ছাকৃতভাবে পরিবর্তন করা হয়নি।

পরীক্ষা:
- পাঁচটি HTML-এর inline JavaScript Node syntax check করা হয়েছে।
- Live Supabase migration / live checkout এখানে চালানো হয়নি; SQL Run এবং নিজের Supabase project-এ end-to-end test আবশ্যক।
