/**
 * ملف الأمراض العامة - GeneralDiseases.js
 * يحتوي على أمراض عامة من مختلف التخصصات الطبية
 * مصمم لتدريب نماذج الذكاء الاصطناعي في التشخيص الطبي العام
 */
export const GeneralDiseases = {
  /**
   * ================================
   * أمراض الجهاز التنفسي
   * Respiratory Diseases
   * ================================
   */
  "Common Cold": {
    nameAr: "الزكام",
    description: "Viral infection of nose and throat",
    descriptionAr: "عدوى فيروسية في الأنف والحلق",
    severity: "low",                     // شدة منخفضة
    category: "Respiratory Infection",   // تصنيف: عدوى تنفسية
    relatedSymptoms: [
      "Runny Nose",                     // سيلان الأنف
      "Sore Throat",                    // التهاب الحلق
      "Cough",                          // سعال
      "Sneezing",                       // عطس
      "Mild Headache",                  // صداع خفيف
      "Low-Grade Fever"                 // حمى منخفضة الدرجة
    ]
  },

  "Influenza": {
    nameAr: "الإنفلونزا",
    description: "Contagious respiratory illness caused by influenza viruses",
    descriptionAr: "مرض تنفسي معدي تسببه فيروسات الإنفلونزا",
    severity: "moderate",                // شدة متوسطة
    category: "Respiratory Infection",   // تصنيف: عدوى تنفسية
    relatedSymptoms: [
      "Fever",                          // حمى
      "Muscle Pain",                    // ألم العضلات
      "Fatigue",                        // تعب
      "Cough",                          // سعال
      "Headache",                       // صداع
      "Sore Throat"                     // التهاب الحلق
    ]
  },

  "Pneumonia": {
    nameAr: "الالتهاب الرئوي",
    description: "Infection that inflames air sacs in one or both lungs",
    descriptionAr: "عدوى تسبب التهاب الحويصلات الهوائية في إحدى الرئتين أو كلتيهما",
    severity: "high",                    // شدة عالية
    category: "Respiratory Infection",   // تصنيف: عدوى تنفسية
    relatedSymptoms: [
      "Chest Pain",                     // ألم الصدر
      "Cough with Phlegm",              // سعال مع بلغم
      "Fever",                          // حمى
      "Shortness of Breath",            // ضيق التنفس
      "Fatigue"                         // تعب
    ]
  },

  "Asthma": {
    nameAr: "الربو",
    description: "Condition in which airways narrow and swell producing extra mucus",
    descriptionAr: "حالة تضيق فيها الممرات الهوائية وتنتفخ وتنتج مخاطًا إضافيًا",
    severity: "moderate",                // شدة متوسطة
    category: "Chronic Respiratory",     // تصنيف: تنفسي مزمن
    relatedSymptoms: [
      "Shortness of Breath",            // ضيق التنفس
      "Wheezing",                       // صفير
      "Chest Tightness",                // ضيق الصدر
      "Coughing",                       // سعال
      "Difficulty Breathing"            // صعوبة في التنفس
    ]
  },

  /**
   * ================================
   * أمراض الجهاز الهضمي
   * Gastrointestinal Diseases
   * ================================
   */
  "Gastroenteritis": {
    nameAr: "التهاب المعدة والأمعاء",
    description: "Inflammation of stomach and intestines",
    descriptionAr: "التهاب المعدة والأمعاء",
    severity: "moderate",                // شدة متوسطة
    category: "Gastrointestinal",        // تصنيف: معوي
    relatedSymptoms: [
      "Diarrhea",                       // إسهال
      "Nausea",                         // غثيان
      "Vomiting",                       // قيء
      "Abdominal Pain",                 // ألم البطن
      "Fever",                          // حمى
      "Loss of Appetite"                // فقدان الشهية
    ]
  },

  "Irritable Bowel Syndrome (IBS)": {
    nameAr: "متلازمة القولون العصبي",
    description: "Common disorder affecting large intestine",
    descriptionAr: "اضطراب شائع يؤثر على الأمعاء الغليظة",
    severity: "moderate",                // شدة متوسطة
    category: "Gastrointestinal",        // تصنيف: معوي
    relatedSymptoms: [
      "Abdominal Pain",                 // ألم البطن
      "Bloating",                       // انتفاخ
      "Gas",                            // غازات
      "Diarrhea",                       // إسهال
      "Constipation"                    // إمساك
    ]
  },

  /**
   * ================================
   * أمراض الغدد الصماء والتمثيل الغذائي
   * Endocrine and Metabolic Diseases
   * ================================
   */
  "Diabetes Mellitus Type 2": {
    nameAr: "داء السكري النوع الثاني",
    description: "Chronic condition affecting how body processes blood sugar",
    descriptionAr: "حالة مزمنة تؤثر على كيفية معالجة الجسم لسكر الدم",
    severity: "high",                    // شدة عالية
    category: "Metabolic",               // تصنيف: أيضي
    relatedSymptoms: [
      "Increased Thirst",               // زيادة العطش
      "Frequent Urination",             // تبول متكرر
      "Increased Hunger",               // زيادة الجوع
      "Fatigue",                        // تعب
      "Blurred Vision"                  // رؤية ضبابية
    ]
  },

  "Hypothyroidism": {
    nameAr: "قصور الغدة الدرقية",
    description: "Underactive thyroid gland producing insufficient hormones",
    descriptionAr: "خمول في الغدة الدرقية ينتج هرمونات غير كافية",
    severity: "moderate",                // شدة متوسطة
    category: "Endocrine",               // تصنيف: غدد صماء
    relatedSymptoms: [
      "Fatigue",                        // تعب
      "Weight Gain",                    // زيادة الوزن
      "Cold Intolerance",               // عدم تحمل البرد
      "Constipation",                   // إمساك
      "Dry Skin"                        // جلد جاف
    ]
  },

  /**
   * ================================
   * أمراض العظام والمفاصل
   * Musculoskeletal Diseases
   * ================================
   */
  "Osteoarthritis": {
    nameAr: "التهاب المفاصل التنكسي",
    description: "Degenerative joint disease causing cartilage breakdown",
    descriptionAr: "مرض مفاصل تنكسي يسبب تدهور الغضروف",
    severity: "moderate",                // شدة متوسطة
    category: "Musculoskeletal",         // تصنيف: عضلي هيكلي
    relatedSymptoms: [
      "Joint Pain",                     // ألم المفاصل
      "Stiffness",                      // تصلب
      "Tenderness",                     // إيلام
      "Loss of Flexibility",            // فقدان المرونة
      "Swelling"                        // تورم
    ]
  },

  "Rheumatoid Arthritis": {
    nameAr: "التهاب المفاصل الروماتويدي",
    description: "Autoimmune disorder causing joint inflammation and damage",
    descriptionAr: "اضطراب مناعي ذاتي يسبب التهاب المفاصل وتلفها",
    severity: "high",                    // شدة عالية
    category: "Musculoskeletal",         // تصنيف: عضلي هيكلي
    relatedSymptoms: [
      "Joint Pain",                     // ألم المفاصل
      "Joint Swelling",                 // تورم المفاصل
      "Joint Stiffness",                // تصلب المفاصل
      "Fatigue",                        // تعب
      "Fever"                           // حمى
    ]
  },

  /**
   * ================================
   * أمراض عصبية
   * Neurological Diseases
   * ================================
   */
  "Migraine": {
    nameAr: "الصداع النصفي",
    description: "Neurological condition causing severe recurrent headaches",
    descriptionAr: "حالة عصبية تسبب صداعًا شديدًا متكررًا",
    severity: "moderate",                // شدة متوسطة
    category: "Neurological",            // تصنيف: عصبي
    relatedSymptoms: [
      "Throbbing Head Pain",            // ألم نابض في الرأس
      "Nausea",                         // غثيان
      "Vomiting",                       // قيء
      "Sensitivity to Light",           // حساسية للضوء
      "Sensitivity to Sound"            // حساسية للصوت
    ]
  },

  "Epilepsy": {
    nameAr: "الصرع",
    description: "Neurological disorder characterized by recurrent seizures",
    descriptionAr: "اضطراب عصبي يتميز بنوبات متكررة",
    severity: "high",                    // شدة عالية
    category: "Neurological",            // تصنيف: عصبي
    relatedSymptoms: [
      "Seizures",                       // نوبات
      "Temporary Confusion",            // ارتباك مؤقت
      "Staring Spells",                 // نوبات التحديق
      "Loss of Consciousness"           // فقدان الوعي
    ]
  },

  /**
   * ================================
   * أمراض نفسية
   * Psychiatric Diseases
   * ================================
   */
  "Major Depressive Disorder": {
    nameAr: "الاكتئاب الشديد",
    description: "Mood disorder causing persistent sadness and loss of interest",
    descriptionAr: "اضطراب المزاج يسبب حزنًا مستمرًا وفقدان الاهتمام",
    severity: "high",                    // شدة عالية
    category: "Psychiatric",             // تصنيف: نفسي
    relatedSymptoms: [
      "Persistent Sadness",             // حزن مستمر
      "Loss of Interest",               // فقدان الاهتمام
      "Changes in Appetite",            // تغيرات في الشهية
      "Sleep Problems",                 // مشاكل النوم
      "Fatigue",                        // تعب
      "Feelings of Worthlessness"       // مشاعر عدم القيمة
    ]
  },

  /**
   * ================================
   * أمراض جلدية
   * Dermatological Diseases
   * ================================
   */
  "Eczema": {
    nameAr: "الإكزيما",
    description: "Chronic skin condition causing inflamed, itchy, and cracked skin",
    descriptionAr: "حالة جلدية مزمنة تسبب التهاب وحكة وتشقق الجلد",
    severity: "moderate",                // شدة متوسطة
    category: "Dermatological",          // تصنيف: جلدي
    relatedSymptoms: [
      "Dry Skin",                       // جلد جاف
      "Intense Itching",                // حكة شديدة
      "Red Patches",                    // بقع حمراء
      "Cracked Skin"                    // جلد متشقق
    ]
  },

  /**
   * ================================
   * أمراض معدية
   * Infectious Diseases
   * ================================
   */
  "COVID-19": {
    nameAr: "كوفيد-19",
    description: "Respiratory illness caused by coronavirus SARS-CoV-2",
    descriptionAr: "مرض تنفسي يسببه فيروس كورونا سارس-كوف-2",
    severity: "moderate",                // شدة متوسطة
    category: "Infectious Disease",      // تصنيف: مرض معدي
    relatedSymptoms: [
      "Fever",                          // حمى
      "Cough",                          // سعال
      "Shortness of Breath",            // ضيق التنفس
      "Fatigue",                        // تعب
      "Loss of Taste/Smell"             // فقدان التذوق/الشم
    ]
  },

  "Tuberculosis": {
    nameAr: "السل",
    description: "Bacterial infection primarily affecting lungs",
    descriptionAr: "عدوى بكتيرية تؤثر بشكل أساسي على الرئتين",
    severity: "high",                    // شدة عالية
    category: "Infectious Disease",      // تصنيف: مرض معدي
    relatedSymptoms: [
      "Persistent Cough",               // سعال مستمر
      "Coughing up Blood",              // سعال مصحوب بدم
      "Chest Pain",                     // ألم الصدر
      "Unintentional Weight Loss",      // فقدان الوزن غير المقصود
      "Night Sweats"                    // تعرق ليلي
    ]
  },

  /**
   * ================================
   * أمراض الدم
   * Hematological Diseases
   * ================================
   */
  "Anemia": {
    nameAr: "فقر الدم",
    description: "Condition with deficiency of red blood cells or hemoglobin",
    descriptionAr: "حالة نقص في خلايا الدم الحمراء أو الهيموجلوبين",
    severity: "moderate",                // شدة متوسطة
    category: "Hematological",           // تصنيف: دم
    relatedSymptoms: [
      "Fatigue",                        // تعب
      "Weakness",                       // ضعف
      "Pale Skin",                      // جلد شاحب
      "Shortness of Breath",            // ضيق التنفس
      "Dizziness"                       // دوخة
    ]
  },

  /**
   * ================================
   * أمراض الكبد
   * Liver Diseases
   * ================================
   */
  "Hepatitis B": {
    nameAr: "التهاب الكبد الوبائي ب",
    description: "Viral infection causing liver inflammation and damage",
    descriptionAr: "عدوى فيروسية تسبب التهاب وتلف الكبد",
    severity: "high",                    // شدة عالية
    category: "Liver Disease",           // تصنيف: مرض كبدي
    relatedSymptoms: [
      "Jaundice",                       // اليرقان (اصفرار الجلد/العين)
      "Dark Urine",                     // بول داكن
      "Fatigue",                        // تعب
      "Nausea",                         // غثيان
      "Abdominal Pain"                  // ألم البطن
    ]
  },

  "Liver Cirrhosis": {
    nameAr: "تليف الكبد",
    description: "Late-stage scarring (fibrosis) of the liver",
    descriptionAr: "مرحلة متأخرة من تندب (تليف) الكبد",
    severity: "critical",                // شدة حرجة
    category: "Liver Disease",           // تصنيف: مرض كبدي
    relatedSymptoms: [
      "Jaundice",                       // اليرقان (اصفرار الجلد/العين)
      "Fatigue",                        // تعب
      "Weight Loss",                    // فقدان الوزن
      "Swelling in Legs",               // تورم في الساقين
      "Ascites"                         // استسقاء (تراكم سوائل البطن)
    ]
  },

  /**
   * ================================
   * أمراض الكلى
   * Kidney Diseases
   * ================================
   */
  "Chronic Kidney Disease": {
    nameAr: "مرض الكلى المزمن",
    description: "Gradual loss of kidney function over time",
    descriptionAr: "فقدان تدريجي لوظائف الكلى بمرور الوقت",
    severity: "high",                    // شدة عالية
    category: "Renal",                   // تصنيف: كلوي
    relatedSymptoms: [
      "Fatigue",                        // تعب
      "Swelling in Ankles",             // تورم في الكاحلين
      "Shortness of Breath",            // ضيق التنفس
      "Nausea",                         // غثيان
      "Blood in Urine"                  // دم في البول
    ]
  },

  "Kidney Stones": {
    nameAr: "حصى الكلى",
    description: "Hard deposits made of minerals and salts that form inside kidneys",
    descriptionAr: "رواسب صلبة من المعادن والأملاح تتشكل داخل الكلى",
    severity: "moderate",                // شدة متوسطة
    category: "Renal",                   // تصنيف: كلوي
    relatedSymptoms: [
      "Severe Flank Pain",              // ألم شديد في الخاصرة
      "Pain on Urination",              // ألم عند التبول
      "Pink, Red or Brown Urine",       // بول وردي، أحمر أو بني
      "Nausea",                         // غثيان
      "Vomiting"                        // قيء
    ]
  },

  /**
   * ================================
   * أمراض عصبية إضافية
   * Additional Neurological Diseases
   * ================================
   */
  "Stroke": {
    nameAr: "السكتة الدماغية",
    description: "Damage to the brain from interruption of its blood supply",
    descriptionAr: "تلف في الدماغ ناتج عن انقطاع إمدادات الدم عنه",
    severity: "critical",                // شدة حرجة
    category: "Neurological",            // تصنيف: عصبي
    relatedSymptoms: [
      "Sudden Numbness",                // تنميل مفاجئ
      "Confusion",                      // ارتباك
      "Trouble Speaking",               // صعوبة في التحدث
      "Vision Problems",                // مشاكل في الرؤية
      "Loss of Balance"                 // فقدان التوازن
    ]
  },

  /**
   * ================================
   * أمراض القلب والأوعية الدموية (عامة)
   * Cardiovascular Diseases (General)
   * ================================
   */
  "Hypertension": {
    nameAr: "ارتفاع ضغط الدم",
    description: "Long-term force of the blood against your artery walls is high",
    descriptionAr: "قوة دفع الدم ضد جدران الشرايين مرتفعة لفترة طويلة",
    severity: "moderate",                // شدة متوسطة
    category: "Cardiovascular",          // تصنيف: قلبي وعائي
    relatedSymptoms: [
      "Headache",                       // صداع
      "Shortness of Breath",            // ضيق التنفس
      "Nosebleeds",                     // نزيف الأنف
      "Dizziness",                      // دوخة
      "Chest Pain"                      // ألم الصدر
    ]
  }
};