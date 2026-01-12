/**
 * ملف الأعراض العامة - GeneralSymptoms.js
 * يحتوي على أعراض طبية عامة من مختلف الأجهزة والأعضاء
 * مصمم لتدريب نماذج الذكاء الاصطناعي في التشخيص الطبي
 */
export const GeneralSymptoms = {
  /**
   * =======================
   * الأعراض التنفسية
   * =======================
   */
  "Cough": {
    nameAr: "السعال",
    description: "Sudden expulsion of air from lungs to clear throat or airways",
    descriptionAr: "إخراج مفاجئ للهواء من الرئتين لتنظيف الحلق أو الممرات الهوائية",
    severity: "low",                    // شدة منخفضة
    category: "Respiratory",           // تصنيف: تنفسي
    relatedDiseases: [
      "Common Cold",                   // الزكام
      "Influenza",                     // الإنفلونزا
      "Bronchitis",                    // التهاب الشعب الهوائية
      "Pneumonia",                     // الالتهاب الرئوي
      "Asthma",                        // الربو
      "COVID-19",                      // كوفيد-19
      "Tuberculosis"                   // السل
    ]
  },

  "Shortness of Breath": {
    nameAr: "ضيق التنفس",
    description: "Difficulty breathing or feeling unable to get enough air",
    descriptionAr: "صعوبة في التنفس أو الشعور بعدم القدرة على الحصول على هواء كافٍ",
    severity: "moderate",              // شدة متوسطة
    category: "Respiratory",           // تصنيف: تنفسي
    relatedDiseases: [
      "Asthma",                        // الربو
      "Chronic Obstructive Pulmonary Disease (COPD)",  // مرض الانسداد الرئوي المزمن
      "Pneumonia",                     // الالتهاب الرئوي
      "Heart Failure",                 // فشل القلب
      "Anemia",                        // فقر الدم
      "Pulmonary Embolism",            // انصمام رئوي
      "Chronic Kidney Disease",        // مرض الكلى المزمن
      "Hypertension"                   // ارتفاع ضغط الدم
    ]
  },

  "Runny Nose": {
    nameAr: "سيلان الأنف",
    description: "Excess nasal drainage ranging from clear fluid to thick mucus",
    descriptionAr: "تصريف أنفي زائد يتراوح من سائل صافٍ إلى مخاط سميك",
    severity: "low",                    // شدة منخفضة
    category: "Respiratory",           // تصنيف: تنفسي
    relatedDiseases: [
      "Common Cold",                   // الزكام
      "Influenza",                     // الإنفلونزا
      "Allergic Rhinitis",             // التهاب الأنف التحسسي
      "Sinusitis",                     // التهاب الجيوب الأنفية
      "COVID-19"                       // كوفيد-19
    ]
  },

  "Sore Throat": {
    nameAr: "التهاب الحلق",
    description: "Pain, scratchiness or irritation of throat that often worsens when swallowing",
    descriptionAr: "ألم، خشونة أو تهيج الحلق الذي غالبًا ما يزداد سوءًا عند البلع",
    severity: "low",                    // شدة منخفضة
    category: "Respiratory",           // تصنيف: تنفسي
    relatedDiseases: [
      "Common Cold",                   // الزكام
      "Influenza",                     // الإنفلونزا
      "Strep Throat",                  // التهاب الحلق العقدي
      "Tonsillitis",                   // التهاب اللوزتين
      "COVID-19",                      // كوفيد-19
      "Mononucleosis"                  // كثرة الوحيدات
    ]
  },

  /**
   * =======================
   * الأعراض الجهازية
   * =======================
   */
  "Fever": {
    nameAr: "الحمى",
    description: "Temporary increase in body temperature, often due to illness",
    descriptionAr: "ارتفاع مؤقت في درجة حرارة الجسم، غالبًا بسبب المرض",
    severity: "moderate",              // شدة متوسطة
    category: "Systemic",              // تصنيف: جهازي
    relatedDiseases: [
      "Common Cold",                   // الزكام
      "Influenza",                     // الإنفلونزا
      "Pneumonia",                     // الالتهاب الرئوي
      "COVID-19",                      // كوفيد-19
      "Urinary Tract Infection (UTI)", // عدوى المسالك البولية
      "Malaria",                       // الملاريا
      "Sepsis"                         // تعفن الدم
    ]
  },

  "Fatigue": {
    nameAr: "التعب",
    description: "Persistent feeling of tiredness, weakness or exhaustion",
    descriptionAr: "شعور مستمر بالتعب، الضعف أو الإرهاق",
    severity: "moderate",              // شدة متوسطة
    category: "Systemic",              // تصنيف: جهازي
    relatedDiseases: [
      "Anemia",                        // فقر الدم
      "Hypothyroidism",                // قصور الغدة الدرقية
      "Chronic Fatigue Syndrome",      // متلازمة التعب المزمن
      "Diabetes",                      // السكري
      "Heart Failure",                 // فشل القلب
      "Depression",                    // الاكتئاب
      "Cancer",                        // السرطان
      "Hepatitis B",                   // التهاب الكبد الوبائي ب
      "Liver Cirrhosis",               // تليف الكبد
      "Chronic Kidney Disease"         // مرض الكلى المزمن
    ]
  },

  /**
   * =======================
   * الأعراض العصبية
   * =======================
   */
  "Headache": {
    nameAr: "الصداع",
    description: "Pain in any region of head, ranging from sharp to dull pain",
    descriptionAr: "ألم في أي منطقة من الرأس، يتراوح من ألم حاد إلى ممل",
    severity: "moderate",              // شدة متوسطة
    category: "Neurological",          // تصنيف: عصبي
    relatedDiseases: [
      "Migraine",                      // الصداع النصفي
      "Tension Headache",              // صداع التوتر
      "Sinusitis",                     // التهاب الجيوب الأنفية
      "Hypertension",                  // ارتفاع ضغط الدم
      "Meningitis",                    // التهاب السحايا
      "COVID-19",                      // كوفيد-19
      "Stroke"                         // السكتة الدماغية
    ]
  },

  "Dizziness": {
    nameAr: "الدوخة",
    description: "Feeling of lightheadedness, unsteadiness, or vertigo",
    descriptionAr: "إحساس بالدوار، عدم الثبات، أو الدوخة",
    severity: "moderate",              // شدة متوسطة
    category: "Neurological",          // تصنيف: عصبي
    relatedDiseases: [
      "Vertigo",                       // الدوار
      "Anemia",                        // فقر الدم
      "Hypotension",                   // انخفاض ضغط الدم
      "Migraine",                      // الصداع النصفي
      "Dehydration",                   // الجفاف
      "Inner Ear Disorders"            // اضطرابات الأذن الداخلية
    ]
  },

  /**
   * =======================
   * الأعراض الهضمية
   * =======================
   */
  "Nausea": {
    nameAr: "الغثيان",
    description: "Unpleasant sensation of wanting to vomit",
    descriptionAr: "إحساس غير سار بالرغبة في التقيؤ",
    severity: "moderate",              // شدة متوسطة
    category: "Gastrointestinal",      // تصنيف: معوي
    relatedDiseases: [
      "Gastroenteritis",               // التهاب المعدة والأمعاء
      "Food Poisoning",                // تسمم غذائي
      "Migraine",                      // الصداع النصفي
      "Pregnancy",                     // الحمل
      "Medication Side Effects",       // آثار جانبية للأدوية
      "Appendicitis",                  // التهاب الزائدة الدودية
      "Hepatitis B",                   // التهاب الكبد الوبائي ب
      "Kidney Stones",                 // حصى الكلى
      "Chronic Kidney Disease"         // مرض الكلى المزمن
    ]
  },

  "Vomiting": {
    nameAr: "التقيؤ",
    description: "Forceful expulsion of stomach contents through mouth",
    descriptionAr: "إخراج قوي لمحتويات المعدة عبر الفم",
    severity: "moderate",              // شدة متوسطة
    category: "Gastrointestinal",      // تصنيف: معوي
    relatedDiseases: [
      "Gastroenteritis",               // التهاب المعدة والأمعاء
      "Food Poisoning",                // تسمم غذائي
      "Migraine",                      // الصداع النصفي
      "Appendicitis",                  // التهاب الزائدة الدودية
      "Pancreatitis",                  // التهاب البنكرياس
      "Intestinal Obstruction",        // انسداد معوي
      "Kidney Stones"                  // حصى الكلى
    ]
  },

  "Diarrhea": {
    nameAr: "الإسهال",
    description: "Loose, watery stools occurring more frequently than usual",
    descriptionAr: "براز رخو، مائي يحدث بشكل متكرر أكثر من المعتاد",
    severity: "moderate",              // شدة متوسطة
    category: "Gastrointestinal",      // تصنيف: معوي
    relatedDiseases: [
      "Gastroenteritis",               // التهاب المعدة والأمعاء
      "Food Poisoning",                // تسمم غذائي
      "Inflammatory Bowel Disease (IBD)",  // مرض الأمعاء الالتهابي
      "Irritable Bowel Syndrome (IBS)",    // متلازمة القولون العصبي
      "Celiac Disease",                // مرض السيلياك
      "COVID-19"                       // كوفيد-19
    ]
  },

  "Abdominal Pain": {
    nameAr: "ألم البطن",
    description: "Pain occurring between chest and pelvic regions",
    descriptionAr: "ألم يحدث بين مناطق الصدر والحوض",
    severity: "moderate",              // شدة متوسطة
    category: "Gastrointestinal",      // تصنيف: معوي
    relatedDiseases: [
      "Gastroenteritis",               // التهاب المعدة والأمعاء
      "Appendicitis",                  // التهاب الزائدة الدودية
      "Gallstones",                    // حصى المرارة
      "Peptic Ulcer Disease",          // قرحة المعدة
      "Irritable Bowel Syndrome (IBS)",// متلازمة القولون العصبي
      "Kidney Stones",                 // حصى الكلى
      "Hepatitis B"                    // التهاب الكبد الوبائي ب
    ]
  },

  /**
   * =======================
   * الأعراض العضلية الهيكلية
   * =======================
   */
  "Joint Pain": {
    nameAr: "ألم المفاصل",
    description: "Discomfort, pain or inflammation arising from any joint",
    descriptionAr: "انزعاج، ألم أو التهاب ينشأ من أي مفصل",
    severity: "moderate",              // شدة متوسطة
    category: "Musculoskeletal",       // تصنيف: عضلي هيكلي
    relatedDiseases: [
      "Osteoarthritis",                // التهاب المفاصل التنكسي
      "Rheumatoid Arthritis",          // التهاب المفاصل الروماتويدي
      "Gout",                          // النقرس
      "Lupus",                         // الذئبة
      "Fibromyalgia",                  // الألم العضلي الليفي
      "Lyme Disease"                   // مرض لايم
    ]
  },

  "Muscle Pain": {
    nameAr: "ألم العضلات",
    description: "Pain affecting one or more muscles",
    descriptionAr: "ألم يؤثر على عضلة واحدة أو أكثر",
    severity: "moderate",              // شدة متوسطة
    category: "Musculoskeletal",       // تصنيف: عضلي هيكلي
    relatedDiseases: [
      "Influenza",                     // الإنفلونزا
      "Fibromyalgia",                  // الألم العضلي الليفي
      "Chronic Fatigue Syndrome",      // متلازمة التعب المزمن
      "Lyme Disease",                  // مرض لايم
      "Polymyalgia Rheumatica",        // التهاب العضلات الروماتيزمي
      "Electrolyte Imbalance"          // اختلال توازن الكهارل
    ]
  },

  /**
   * =======================
   * الأعراض الجلدية
   * =======================
   */
  "Skin Rash": {
    nameAr: "طفح جلدي",
    description: "Change in skin color or texture, often with itching or redness",
    descriptionAr: "تغير في لون الجلد أو قوامه، غالبًا مع حكة أو احمرار",
    severity: "low",                   // شدة منخفضة
    category: "Dermatological",        // تصنيف: جلدي
    relatedDiseases: [
      "Eczema",                        // الإكزيما
      "Psoriasis",                     // الصدفية
      "Contact Dermatitis",            // التهاب الجلد التماسي
      "Shingles",                      // القوباء المنطقية
      "Measles",                       // الحصبة
      "Allergic Reaction"              // رد فعل تحسسي
    ]
  },

  /**
   * =======================
   * أعراض الوزن
   * =======================
   */
  "Weight Loss": {
    nameAr: "فقدان الوزن",
    description: "Decrease in body weight from normal or healthy range",
    descriptionAr: "انخفاض في وزن الجسم من النطاق الطبيعي أو الصحي",
    severity: "high",                  // شدة عالية
    category: "Systemic",              // تصنيف: جهازي
    relatedDiseases: [
      "Cancer",                        // السرطان
      "Hyperthyroidism",               // فرط نشاط الغدة الدرقية
      "Diabetes",                      // السكري
      "Tuberculosis",                  // السل
      "HIV/AIDS",                      // فيروس نقص المناعة البشرية/الإيدز
      "Inflammatory Bowel Disease (IBD)"  // مرض الأمعاء الالتهابي
    ]
  },

  "Weight Gain": {
    nameAr: "زيادة الوزن",
    description: "Increase in body weight above normal or healthy range",
    descriptionAr: "زيادة في وزن الجسم فوق النطاق الطبيعي أو الصحي",
    severity: "moderate",              // شدة متوسطة
    category: "Systemic",              // تصنيف: جهازي
    relatedDiseases: [
      "Hypothyroidism",                // قصور الغدة الدرقية
      "Cushing's Syndrome",            // متلازمة كوشينغ
      "Polycystic Ovary Syndrome (PCOS)", // متلازمة المبيض المتعدد الكيسات
      "Depression",                    // الاكتئاب
      "Heart Failure"                  // فشل القلب
    ]
  },

  /**
   * =======================
   * أعراض القلب والأوعية الدموية
   * =======================
   */
  "Chest Pain": {
    nameAr: "ألم الصدر",
    description: "Pain or discomfort in chest area",
    descriptionAr: "ألم أو انزعاج في منطقة الصدر",
    severity: "high",                  // شدة عالية
    category: "Cardiovascular",        // تصنيف: قلبي وعائي
    relatedDiseases: [
      "Heart Attack",                  // نوبة قلبية
      "Angina",                        // ذبحة صدرية
      "Pneumonia",                     // الالتهاب الرئوي
      "Pulmonary Embolism",            // انصمام رئوي
      "Costochondritis",               // التهاب الغضروف الضلعي
      "Gastroesophageal Reflux Disease (GERD)" // مرض ارتجاع المريء
    ]
  },

  /**
   * =======================
   * أعراض إضافية
   * =======================
   */
  "Back Pain": {
    nameAr: "ألم الظهر",
    description: "Pain in back region, ranging from dull constant ache to sudden sharp pain",
    descriptionAr: "ألم في منطقة الظهر، يتراوح من ألم ممل مستمر إلى ألم حاد مفاجئ",
    severity: "moderate",              // شدة متوسطة
    category: "Musculoskeletal",       // تصنيف: عضلي هيكلي
    relatedDiseases: [
      "Muscle Strain",                 // إجهاد عضلي
      "Herniated Disc",                // انزلاق غضروفي
      "Osteoporosis",                  // هشاشة العظام
      "Arthritis",                     // التهاب المفاصل
      "Kidney Stones",                 // حصى الكلى
      "Spinal Stenosis"                // تضيق العمود الفقري
    ]
  },

  "Loss of Appetite": {
    nameAr: "فقدان الشهية",
    description: "Reduced desire to eat",
    descriptionAr: "انخفاض الرغبة في تناول الطعام",
    severity: "moderate",              // شدة متوسطة
    category: "Gastrointestinal",      // تصنيف: معوي
    relatedDiseases: [
      "Gastroenteritis",               // التهاب المعدة والأمعاء
      "Depression",                    // الاكتئاب
      "Cancer",                        // السرطان
      "Liver Disease",                 // مرض الكبد
      "Kidney Disease",                // مرض الكلى
      "HIV/AIDS"                       // فيروس نقص المناعة البشرية/الإيدز
    ]
  },

  "Insomnia": {
    nameAr: "الأرق",
    description: "Persistent difficulty falling or staying asleep",
    descriptionAr: "صعوبة مستمرة في النوم أو البقاء نائمًا",
    severity: "moderate",              // شدة متوسطة
    category: "Neurological",          // تصنيف: عصبي
    relatedDiseases: [
      "Anxiety Disorders",             // اضطرابات القلق
      "Depression",                    // الاكتئاب
      "Chronic Pain",                  // ألم مزمن
      "Restless Legs Syndrome",        // متلازمة تململ الساقين
      "Sleep Apnea",                   // انقطاع النفس النومي
      "Hyperthyroidism"                // فرط نشاط الغدة الدرقية
    ]
  },

  "Frequent Urination": {
    nameAr: "التبول المتكرر",
    description: "Need to urinate more often than usual",
    descriptionAr: "الحاجة إلى التبول أكثر من المعتاد",
    severity: "moderate",              // شدة متوسطة
    category: "Urological",            // تصنيف: بولي
    relatedDiseases: [
      "Urinary Tract Infection (UTI)", // عدوى المسالك البولية
      "Diabetes",                      // السكري
      "Prostate Enlargement",          // تضخم البروستاتا
      "Interstitial Cystitis",         // التهاب المثانة الخلالي
      "Overactive Bladder",            // المثانة مفرطة النشاط
      "Pregnancy"                      // الحمل
    ]
  },

  /**
   * =======================
   * أعراض الكبد
   * =======================
   */
  "Jaundice": {
    nameAr: "اليرقان",
    description: "Yellowing of the skin and eyes",
    descriptionAr: "اصفرار الجلد والعينين",
    severity: "high",                  // شدة عالية
    category: "Hepatic",               // تصنيف: كبدي
    relatedDiseases: [
      "Hepatitis B",                   // التهاب الكبد الوبائي ب
      "Liver Cirrhosis",               // تليف الكبد
      "Gallstones",                    // حصى المرارة
      "Liver Cancer",                  // سرطان الكبد
      "Pancreatic Cancer"              // سرطان البنكرياس
    ]
  },

  "Dark Urine": {
    nameAr: "بول داكن",
    description: "Urine that looks darker than normal",
    descriptionAr: "بول يبدو أغمق من المعتاد",
    severity: "moderate",              // شدة متوسطة
    category: "Hepatic/Renal",         // تصنيف: كبدي/كلوي
    relatedDiseases: [
      "Hepatitis B",                   // التهاب الكبد الوبائي ب
      "Dehydration",                   // الجفاف
      "Liver Cirrhosis",               // تليف الكبد
      "Gallstones"                     // حصى المرارة
    ]
  },

  /**
   * =======================
   * أعراض الكلى
   * =======================
   */
  "Blood in Urine": {
    nameAr: "دم في البول",
    description: "Presence of red blood cells in urine (Hematuria)",
    descriptionAr: "وجود خلايا دم حمراء في البول (بيلة دموية)",
    severity: "high",                  // شدة عالية
    category: "Urological",            // تصنيف: بولي
    relatedDiseases: [
      "Kidney Stones",                 // حصى الكلى
      "Urinary Tract Infection (UTI)", // عدوى المسالك البولية
      "Bladder Cancer",                // سرطان المثانة
      "Kidney Cancer",                 // سرطان الكلى
      "Chronic Kidney Disease"         // مرض الكلى المزمن
    ]
  },

  "Flank Pain": {
    nameAr: "ألم الخاصرة",
    description: "Pain in the side of the body between ribs and hip",
    descriptionAr: "ألم في جانب الجسم بين الأضلاع والورك",
    severity: "moderate",              // شدة متوسطة
    category: "Musculoskeletal/Renal", // تصنيف: عضلي/كلوي
    relatedDiseases: [
      "Kidney Stones",                 // حصى الكلى
      "Kidney Infection",              // عدوى الكلى
      "Muscle Strain",                 // إجهاد عضلي
      "Shingles"                       // القوباء المنطقية
    ]
  },

  /**
   * =======================
   * أعراض عامة إضافية
   * =======================
   */
  "Edema": {
    nameAr: "الوذمة",
    description: "Swelling caused by excess fluid trapped in body's tissues",
    descriptionAr: "تورم ناتج عن سوائل زائدة محبوسة في أنسجة الجسم",
    severity: "moderate",              // شدة متوسطة
    category: "Systemic",              // تصنيف: جهازي
    relatedDiseases: [
      "Heart Failure",                 // فشل القلب
      "Kidney Disease",                // مرض الكلى
      "Liver Cirrhosis",               // تليف الكبد
      "Pregnancy",                     // الحمل
      "Deep Vein Thrombosis (DVT)"     // تجلط الأوردة العميقة
    ]
  }
};