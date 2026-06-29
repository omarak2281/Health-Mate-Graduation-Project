/**
 * ملف الأعراض القلبية - HeartSymptoms.js
 * يحتوي على أعراض متخصصة للقلب والأوعية الدموية
 * مصمم لتدريب نماذج متخصصة في التشخيص القلبي
 */
export const HeartSymptoms = {
  /**
   * ================================
   * أعراض الألم القلبي
   * Cardiac Pain Symptoms
   * ================================
   */
  "Chest Pain": {
    nameAr: "ألم الصدر",
    description: "Pain or discomfort in the chest area that may indicate heart problems",
    descriptionAr: "ألم أو انزعاج في منطقة الصدر قد يشير إلى مشاكل قلبية",
    severity: "high",                    // شدة عالية
    category: "Cardiac Pain",            // فئة: ألم قلبي
    relatedDiseases: [
      "Coronary Artery Disease",        // مرض الشريان التاجي
      "Acute Myocardial Infarction",    // احتشاء عضلة القلب الحاد
      "Angina Pectoris",                // الذبحة الصدرية
      "Unstable Angina",                // الذبحة غير المستقرة
      "Myocarditis",                    // التهاب عضلة القلب
      "Pericarditis",                   // التهاب التامور
      "Pulmonary Hypertension",         // ارتفاع ضغط الدم الرئوي
      "Aortic Aneurysm"                 // تمدد الأوعية الدموية الأبهري
    ]
  },

  "Angina Pectoris": {
    nameAr: "الذبحة الصدرية",
    description: "Chest pain caused by reduced blood flow to the heart muscle",
    descriptionAr: "ألم صدري ناتج عن انخفاض تدفق الدم إلى عضلة القلب",
    severity: "high",                    // شدة عالية
    category: "Cardiac Pain",            // فئة: ألم قلبي
    relatedDiseases: [
      "Coronary Artery Disease",        // مرض الشريان التاجي
      "Stable Angina",                  // الذبحة المستقرة
      "Unstable Angina",                // الذبحة غير المستقرة
      "Aortic Stenosis",                // تضيق الصمام الأبهري
      "Hypertrophic Cardiomyopathy"     // اعتلال عضلة القلب الضخامي
    ]
  },

  /**
   * ================================
   * أعراض ضيق التنفس القلبي
   * Cardiac Respiratory Symptoms
   * ================================
   */
  "Shortness of Breath": {
    nameAr: "ضيق التنفس",
    description: "Difficulty breathing or feeling unable to get enough air",
    descriptionAr: "صعوبة في التنفس أو الشعور بعدم القدرة على الحصول على هواء كافٍ",
    severity: "high",                    // شدة عالية
    category: "Respiratory",             // فئة: تنفسي
    relatedDiseases: [
      "Heart Failure",                  // فشل القلب
      "Congestive Heart Failure",       // فشل القلب الاحتقاني
      "Acute Heart Failure",            // فشل القلب الحاد
      "Pulmonary Edema",                // وذمة رئوية
      "Cardiomyopathy",                 // اعتلال عضلة القلب
      "Pulmonary Hypertension",         // ارتفاع ضغط الدم الرئوي
      "Atrial Septal Defect (ASD)",     // عيت الحاجز الأذيني
      "Aortic Aneurysm"                 // تمدد الأوعية الدموية الأبهري
    ]
  },

  "Orthopnea": {
    nameAr: "ضيق النفس عند الاستلقاء",
    description: "Shortness of breath that occurs when lying flat and improves when sitting up",
    descriptionAr: "ضيق التنفس الذي يحدث عند الاستلقاء ويتحسن عند الجلوس",
    severity: "high",                    // شدة عالية
    category: "Respiratory",             // فئة: تنفسي
    relatedDiseases: [
      "Congestive Heart Failure",       // فشل القلب الاحتقاني
      "Left Ventricular Failure",       // فشل البطين الأيسر
      "Mitral Stenosis",                // تضيق الصمام التاجي
      "Aortic Regurgitation",           // قصور الصمام الأبهري
      "Cardiomyopathy"                  // اعتلال عضلة القلب
    ]
  },

  "Paroxysmal Nocturnal Dyspnea": {
    nameAr: "ضيق النفس الليلي الانتيابي",
    description: "Sudden episodes of shortness of breath that wake the person from sleep",
    descriptionAr: "نوبات مفاجئة من ضيق التنفس توقظ الشخص من النوم",
    severity: "high",                    // شدة عالية
    category: "Respiratory",             // فئة: تنفسي
    relatedDiseases: [
      "Congestive Heart Failure",       // فشل القلب الاحتقاني
      "Left Heart Failure",             // فشل القلب الأيسر
      "Mitral Stenosis",                // تضيق الصمام التاجي
      "Cardiac Asthma"                  // ربو قلبي
    ]
  },

  /**
   * ================================
   * أعراض اضطراب النظم
   * Arrhythmia Symptoms
   * ================================
   */
  "Palpitations": {
    nameAr: "خفقان القلب",
    description: "Awareness of abnormal heartbeats, either too fast, too strong, or irregular",
    descriptionAr: "إدراك دقات قلب غير طبيعية، إما سريعة جدًا، قوية جدًا، أو غير منتظمة",
    severity: "moderate",                // شدة متوسطة
    category: "Arrhythmia",              // فئة: اضطراب النظم
    relatedDiseases: [
      "Atrial Fibrillation",            // الرجفان الأذيني
      "Atrial Flutter",                 // الرفرفة الأذينية
      "Supraventricular Tachycardia",   // تسرع القلب فوق البطيني
      "Ventricular Tachycardia",        // تسرع القلب البطيني
      "Wolff-Parkinson-White Syndrome", // متلازمة وولف باركنسون وايت
      "Sick Sinus Syndrome"             // متلازمة العقدة الجيبية المريضة
    ]
  },

  "Tachycardia": {
    nameAr: "تسرع القلب",
    description: "Heart rate faster than 100 beats per minute at rest",
    descriptionAr: "معدل ضربات القلب أسرع من 100 نبضة في الدقيقة أثناء الراحة",
    severity: "moderate",                // شدة متوسطة
    category: "Arrhythmia",              // فئة: اضطراب النظم
    relatedDiseases: [
      "Supraventricular Tachycardia",   // تسرع القلب فوق البطيني
      "Ventricular Tachycardia",        // تسرع القلب البطيني
      "Atrial Fibrillation",            // الرجفان الأذيني
      "Heart Failure",                  // فشل القلب
      "Hyperthyroidism"                 // فرط نشاط الغدة الدرقية
    ]
  },

  /**
   * ================================
   * أعراض فشل القلب
   * Heart Failure Symptoms
   * ================================
   */
  "Peripheral Edema": {
    nameAr: "الوذمة المحيطية",
    description: "Swelling in the legs, ankles, and feet due to fluid accumulation",
    descriptionAr: "تورم في الساقين والكاحلين والقدمين بسبب تراكم السوائل",
    severity: "moderate",                // شدة متوسطة
    category: "Heart Failure",           // فئة: فشل القلب
    relatedDiseases: [
      "Right Heart Failure",            // فشل القلب الأيمن
      "Congestive Heart Failure",       // فشل القلب الاحتقاني
      "Biventricular Failure",          // فشل ثنائي البطين
      "Tricuspid Regurgitation",        // قصور الصمام ثلاثي الشرفات
      "Constrictive Pericarditis",      // التهاب التامور المقيد
      "Deep Vein Thrombosis (DVT)",     // تجلط الأوردة العميقة
      "Pulmonary Hypertension"          // ارتفاع ضغط الدم الرئوي
    ]
  },

  "Jugular Venous Distension": {
    nameAr: "انتفاخ الوريد الوداجي",
    description: "Visible bulging of the jugular veins in the neck",
    descriptionAr: "انتفاخ مرئي في أوردة الرقبة الوداجية",
    severity: "high",                    // شدة عالية
    category: "Heart Failure",           // فئة: فشل القلب
    relatedDiseases: [
      "Right Heart Failure",            // فشل القلب الأيمن
      "Congestive Heart Failure",       // فشل القلب الاحتقاني
      "Cardiac Tamponade",              // الدكاك القلبي
      "Constrictive Pericarditis",      // التهاب التامور المقيد
      "Tricuspid Regurgitation"         // قصور الصمام ثلاثي الشرفات
    ]
  },

  /**
   * ================================
   * أعراض النفخات القلبية
   * Heart Murmur Symptoms
   * ================================
   */
  "Heart Murmur": {
    nameAr: "النفخة القلبية",
    description: "Abnormal heart sounds heard through a stethoscope",
    descriptionAr: "أصوات قلب غير طبيعية تسمع من خلال السماعة الطبية",
    severity: "moderate",                // شدة متوسطة
    category: "Valvular",                // فئة: صمامات
    relatedDiseases: [
      "Aortic Stenosis",                // تضيق الصمام الأبهري
      "Aortic Regurgitation",           // قصور الصمام الأبهري
      "Mitral Stenosis",                // تضيق الصمام التاجي
      "Mitral Regurgitation",           // قصور الصمام التاجي
      "Endocarditis",                   // التهاب الشغاف
      "Rheumatic Heart Disease"         // مرض القلب الروماتيزمي
    ]
  },

  /**
   * ================================
   * أعراض طارئة قلبية
   * Cardiac Emergency Symptoms
   * ================================
   */
  "Crushing Chest Pain": {
    nameAr: "ألم صدري ساحق",
    description: "Severe, intense chest pain that feels like heavy pressure",
    descriptionAr: "ألم صدري شديد وحاد يشعر وكأنه ضغط ثقيل",
    severity: "critical",                // شدة حرجة
    category: "Emergency",               // فئة: طوارئ
    relatedDiseases: [
      "Acute Myocardial Infarction",    // احتشاء عضلة القلب الحاد
      "Unstable Angina",                // الذبحة غير المستقرة
      "Aortic Dissection",              // تسلخ الأبهر
      "Pericarditis",                   // التهاب التامور
      "Pulmonary Embolism"              // انصمام رئوي
    ]
  },

  "Sudden Loss of Consciousness": {
    nameAr: "فقدان مفاجئ للوعي",
    description: "Abrupt loss of consciousness without warning",
    descriptionAr: "فقدان مفاجئ للوعي بدون سابق إنذار",
    severity: "critical",                // شدة حرجة
    category: "Emergency",               // فئة: طوارئ
    relatedDiseases: [
      "Cardiac Arrest",                 // توقف القلب
      "Ventricular Fibrillation",       // الرجفان البطيني
      "Ventricular Tachycardia",        // تسرع القلب البطيني
      "Complete Heart Block",           // حصار قلبي كامل
      "Pulmonary Embolism"              // انصمام رئوي
    ]
  },

  "Cardiac Arrest": {
    nameAr: "السكتة القلبية",
    description: "Sudden cessation of heart function and blood circulation",
    descriptionAr: "توقف مفاجئ لوظيفة القلب والدورة الدموية",
    severity: "critical",                // شدة حرجة
    category: "Emergency",               // فئة: طوارئ
    relatedDiseases: [
      "Ventricular Fibrillation",       // الرجفان البطيني
      "Ventricular Tachycardia",        // تسرع القلب البطيني
      "Asystole",                       // توقف الانقباض
      "Myocardial Infarction",          // احتشاء عضلة القلب
      "Electrolyte Imbalance"           // اختلال التوازن الكهربائي
    ]
  },

  /**
   * ================================
   * أعراض التهابية قلبية
   * Cardiac Inflammatory Symptoms
   * ================================
   */
  "Fever": {
    nameAr: "الحمى",
    description: "Elevated body temperature above normal range",
    descriptionAr: "ارتفاع درجة حرارة الجسم فوق المعدل الطبيعي",
    severity: "moderate",                // شدة متوسطة
    category: "Inflammatory",            // فئة: التهابي
    relatedDiseases: [
      "Infective Endocarditis",         // التهاب الشغاف العدوائي
      "Myocarditis",                    // التهاب عضلة القلب
      "Pericarditis",                   // التهاب التامور
      "Rheumatic Fever",                // الحمى الروماتيزمية
      "Post-cardiac Surgery Infection"  // عدوى ما بعد جراحة القلب
    ]
  },

  "Chills": {
    nameAr: "القشعريرة",
    description: "Sensation of cold with shivering",
    descriptionAr: "إحساس بالبرودة مع رعشة",
    severity: "moderate",                // شدة متوسطة
    category: "Inflammatory",            // فئة: التهابي
    relatedDiseases: [
      "Infective Endocarditis",         // التهاب الشغاف العدوائي
      "Myocarditis",                    // التهاب عضلة القلب
      "Pericarditis",                   // التهاب التامور
      "Sepsis",                         // تعفن الدم
      "Bacteremia"                      // بكتيريا الدم
    ]
  },

  /**
   * ================================
   * أعراض عصبية قلبية
   * Cardiac Neurological Symptoms
   * ================================
   */
  "Syncope": {
    nameAr: "الإغماء",
    description: "Temporary loss of consciousness due to decreased blood flow to the brain",
    descriptionAr: "فقدان مؤقت للوعي بسبب انخفاض تدفق الدم إلى الدماغ",
    severity: "high",                    // شدة عالية
    category: "Neurological",            // فئة: عصبي
    relatedDiseases: [
      "Cardiac Syncope",                // إغماء قلبي
      "Vasovagal Syncope",              // إغماء وعائي مبهمي
      "Aortic Stenosis",                // تضيق الصمام الأبهري
      "Hypertrophic Cardiomyopathy",    // اعتلال عضلة القلب الضخامي
      "Pulmonary Hypertension",         // ارتفاع ضغط الدم الرئوي
      "Arrhythmias"                     // اضطرابات النظم
    ]
  },

  /**
   * ================================
   * أعراض وعائية
   * Vascular Symptoms
   * ================================
   */
  "Claudication": {
    nameAr: "العرج",
    description: "Pain in legs induced by exercise, caused by obstruction of arteries",
    descriptionAr: "ألم في الساقين يسببه التمرين، ناتج عن انسداد الشرايين",
    severity: "moderate",                // شدة متوسطة
    category: "Vascular",                // فئة: وعائي
    relatedDiseases: [
      "Peripheral Artery Disease",      // مرض الشريان المحيطي
      "Deep Vein Thrombosis (DVT)",     // تجلط الأوردة العميقة
      "Aortic Aneurysm",                // تمدد الأوعية الدموية الأبهري
      "Atherosclerosis"                 // تصلب الشرايين
    ]
  },

  "Cyanosis": {
    nameAr: "الزرقة",
    description: "Bluish discoloration of skin due to poor circulation or inadequate oxygenation",
    descriptionAr: "تلون مزرق للجلد بسبب ضعف الدورة الدموية أو عدم كفاية الأكسجين",
    severity: "high",                    // شدة عالية
    category: "Vascular/Respiratory",    // فئة: وعائي/تنفسي
    relatedDiseases: [
      "Congenital Heart Defects",       // عيوب القلب الخلقية
      "Pulmonary Hypertension",         // ارتفاع ضغط الدم الرئوي
      "Heart Failure",                  // فشل القلب
      "Severe Pneumonia",               // التهاب رئوي حاد
      "COPD"                            // مرض الانسداد الرئوي المزمن
    ]
  }
};