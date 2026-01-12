/**
 * ملف أمراض القلب - HeartDiseases.js
 * يحتوي على أمراض القلب والأوعية الدموية الشاملة
 * مصمم لتدريب نماذج الذكاء الاصطناعي في التشخيص القلبي
 */
export const HeartDiseases = {
  /**
   * ================================
   * أمراض الشرايين التاجية
   * Coronary Artery Diseases
   * ================================
   */
  "Coronary Artery Disease": {
    nameAr: "مرض الشريان التاجي",
    description: "Narrowing or blockage of coronary arteries that supply blood to heart muscle",
    descriptionAr: "ضيق أو انسداد في الشرايين التاجية التي تزود عضلة القلب بالدم",
    severity: "high",                    // شدة عالية
    category: "Coronary Artery Disease", // فئة: أمراض الشرايين التاجية
    relatedSymptoms: [
      "Chest Pain",                     // ألم الصدر
      "Shortness of Breath",            // ضيق التنفس
      "Fatigue",                        // تعب
      "Palpitations",                   // خفقان القلب
      "Nausea",                         // غثيان
      "Dizziness"                       // دوخة
    ]
  },

  "Acute Myocardial Infarction": {
    nameAr: "احتشاء عضلة القلب الحاد",
    description: "Sudden blockage of coronary artery causing death of heart muscle tissue",
    descriptionAr: "انسداد مفاجئ في الشريان التاجي يسبب موت نسيج عضلة القلب",
    severity: "critical",                // شدة حرجة
    category: "Coronary Artery Disease", // فئة: أمراض الشرايين التاجية
    relatedSymptoms: [
      "Crushing Chest Pain",            // ألم صدري ساحق
      "Radiating Pain to Left Arm",     // ألم ينتشر للذراع الأيسر
      "Profuse Sweating",               // تعرق غزير
      "Shortness of Breath",            // ضيق التنفس
      "Nausea",                         // غثيان
      "Sense of Impending Doom"         // شعور بالموت الوشيك
    ]
  },

  "Stable Angina": {
    nameAr: "الذبحة الصدرية المستقرة",
    description: "Predictable chest pain triggered by physical exertion or emotional stress",
    descriptionAr: "ألم صدري متوقع يحدث بسبب المجهود البدني أو التوتر العاطفي",
    severity: "moderate",                // شدة متوسطة
    category: "Coronary Artery Disease", // فئة: أمراض الشرايين التاجية
    relatedSymptoms: [
      "Chest Pain",                     // ألم الصدر
      "Shortness of Breath",            // ضيق التنفس
      "Fatigue",                        // تعب
      "Nausea"                          // غثيان
    ]
  },

  /**
   * ================================
   * فشل القلب
   * Heart Failure
   * ================================
   */
  "Heart Failure": {
    nameAr: "فشل القلب",
    description: "Heart's inability to pump enough blood to meet body's needs",
    descriptionAr: "عجز القلب عن ضخ كمية كافية من الدم لتلبية احتياجات الجسم",
    severity: "high",                    // شدة عالية
    category: "Heart Failure",           // فئة: فشل القلب
    relatedSymptoms: [
      "Shortness of Breath",            // ضيق التنفس
      "Fatigue",                        // تعب
      "Peripheral Edema",               // وذمة محيطية
      "Weight Gain",                    // زيادة الوزن
      "Cough",                          // سعال
      "Palpitations"                    // خفقان القلب
    ]
  },

  "Congestive Heart Failure": {
    nameAr: "فشل القلب الاحتقاني",
    description: "Heart failure with fluid accumulation in lungs and other tissues",
    descriptionAr: "فشل القلب مع تراكم السوائل في الرئتين والأنسجة الأخرى",
    severity: "high",                    // شدة عالية
    category: "Heart Failure",           // فئة: فشل القلب
    relatedSymptoms: [
      "Shortness of Breath",            // ضيق التنفس
      "Peripheral Edema",               // وذمة محيطية
      "Weight Gain",                    // زيادة الوزن
      "Fatigue",                        // تعب
      "Cough",                          // سعال
      "Pink Frothy Sputum"              // بلغم وردي رغوي
    ]
  },

  /**
   * ================================
   * أمراض صمامات القلب
   * Valvular Heart Diseases
   * ================================
   */
  "Aortic Stenosis": {
    nameAr: "تضيق الصمام الأبهري",
    description: "Narrowing of aortic valve opening restricting blood flow from heart",
    descriptionAr: "ضيق في فتحة الصمام الأبهري يحد من تدفق الدم من القلب",
    severity: "high",                    // شدة عالية
    category: "Valvular Heart Disease",  // فئة: مرض صمامات القلب
    relatedSymptoms: [
      "Chest Pain",                     // ألم الصدر
      "Shortness of Breath",            // ضيق التنفس
      "Syncope",                        // إغماء
      "Dizziness",                      // دوخة
      "Heart Murmur",                   // نفخة قلبية
      "Fatigue"                         // تعب
    ]
  },

  "Mitral Regurgitation": {
    nameAr: "قصور الصمام التاجي",
    description: "Leakage of mitral valve causing backflow of blood into left atrium",
    descriptionAr: "تسرب في الصمام التاجي يسبب ارتداد الدم إلى الأذين الأيسر",
    severity: "moderate",                // شدة متوسطة
    category: "Valvular Heart Disease",  // فئة: مرض صمامات القلب
    relatedSymptoms: [
      "Shortness of Breath",            // ضيق التنفس
      "Fatigue",                        // تعب
      "Weakness",                       // ضعف
      "Palpitations",                   // خفقان القلب
      "Heart Murmur"                    // نفخة قلبية
    ]
  },

  /**
   * ================================
   * اعتلالات عضلة القلب
   * Cardiomyopathies
   * ================================
   */
  "Dilated Cardiomyopathy": {
    nameAr: "اعتلال عضلة القلب التوسعي",
    description: "Enlargement and weakening of heart muscle leading to pumping dysfunction",
    descriptionAr: "تضخم وضعف عضلة القلب مما يؤدي إلى خلل في الضخ",
    severity: "high",                    // شدة عالية
    category: "Cardiomyopathy",          // فئة: اعتلال عضلة القلب
    relatedSymptoms: [
      "Shortness of Breath",            // ضيق التنفس
      "Fatigue",                        // تعب
      "Peripheral Edema",               // وذمة محيطية
      "Palpitations",                   // خفقان القلب
      "Dizziness",                      // دوخة
      "Reduced Exercise Tolerance"      // انخفاض تحمل الجهد
    ]
  },

  "Hypertrophic Cardiomyopathy": {
    nameAr: "اعتلال عضلة القلب الضخامي",
    description: "Abnormal thickening of heart muscle, especially interventricular septum",
    descriptionAr: "تثخن غير طبيعي لعضلة القلب، خاصة الحاجز بين البطينين",
    severity: "high",                    // شدة عالية
    category: "Cardiomyopathy",          // فئة: اعتلال عضلة القلب
    relatedSymptoms: [
      "Shortness of Breath",            // ضيق التنفس
      "Chest Pain",                     // ألم الصدر
      "Palpitations",                   // خفقان القلب
      "Syncope",                        // إغماء
      "Dizziness",                      // دوخة
      "Heart Murmur"                    // نفخة قلبية
    ]
  },

  /**
   * ================================
   * اضطرابات النظم القلبية
   * Arrhythmias
   * ================================
   */
  "Atrial Fibrillation": {
    nameAr: "الرجفان الأذيني",
    description: "Irregular and often rapid heart rhythm originating in atria",
    descriptionAr: "إيقاع قلب غير منتظم وغالبًا سريع ينشأ في الأذينين",
    severity: "high",                    // شدة عالية
    category: "Arrhythmia",              // فئة: اضطراب النظم
    relatedSymptoms: [
      "Palpitations",                   // خفقان القلب
      "Irregular Heartbeat",            // نبض قلب غير منتظم
      "Shortness of Breath",            // ضيق التنفس
      "Fatigue",                        // تعب
      "Dizziness",                      // دوخة
      "Anxiety"                         // قلق
    ]
  },

  "Ventricular Tachycardia": {
    nameAr: "تسرع القلب البطيني",
    description: "Rapid heart rhythm originating in ventricles, potentially life-threatening",
    descriptionAr: "إيقاع قلب سريع ينشأ في البطينين، قد يهدد الحياة",
    severity: "critical",                // شدة حرجة
    category: "Arrhythmia",              // فئة: اضطراب النظم
    relatedSymptoms: [
      "Palpitations",                   // خفقان القلب
      "Dizziness",                      // دوخة
      "Shortness of Breath",            // ضيق التنفس
      "Chest Pain",                     // ألم الصدر
      "Syncope",                        // إغماء
      "Loss of Consciousness"           // فقدان الوعي
    ]
  },

  /**
   * ================================
   * أمراض التهابية قلبية
   * Inflammatory Heart Diseases
   * ================================
   */
  "Myocarditis": {
    nameAr: "التهاب عضلة القلب",
    description: "Inflammation of heart muscle usually caused by viral infection",
    descriptionAr: "التهاب عضلة القلب عادةً بسبب عدوى فيروسية",
    severity: "high",                    // شدة عالية
    category: "Inflammatory Heart Disease",  // فئة: مرض قلبي التهابي
    relatedSymptoms: [
      "Chest Pain",                     // ألم الصدر
      "Shortness of Breath",            // ضيق التنفس
      "Fatigue",                        // تعب
      "Fever",                          // حمى
      "Palpitations",                   // خفقان القلب
      "Heart Murmur"                    // نفخة قلبية
    ]
  },

  "Pericarditis": {
    nameAr: "التهاب التامور",
    description: "Inflammation of pericardium, the sac-like membrane around heart",
    descriptionAr: "التهاب التامور، الغشاء الشبيه بالكيس المحيط بالقلب",
    severity: "moderate",                // شدة متوسطة
    category: "Inflammatory Heart Disease",  // فئة: مرض قلبي التهابي
    relatedSymptoms: [
      "Chest Pain",                     // ألم الصدر
      "Fever",                          // حمى
      "Shortness of Breath",            // ضيق التنفس
      "Fatigue",                        // تعب
      "Palpitations",                   // خفقان القلب
      "Cough"                           // سعال
    ]
  },

  "Infective Endocarditis": {
    nameAr: "التهاب الشغاف العدوائي",
    description: "Infection of inner lining of heart chambers and valves",
    descriptionAr: "عدوى في البطانة الداخلية لحجرات القلب والصمامات",
    severity: "critical",                // شدة حرجة
    category: "Inflammatory Heart Disease",  // فئة: مرض قلبي التهابي
    relatedSymptoms: [
      "Fever",                          // حمى
      "Chills",                         // قشعريرة
      "Night Sweats",                   // تعرق ليلي
      "Fatigue",                        // تعب
      "Heart Murmur",                   // نفخة قلبية
      "Shortness of Breath"             // ضيق التنفس
    ]
  },

  /**
   * ================================
   * أمراض الأوعية الدموية
   * Vascular Diseases
   * ================================
   */
  "Pulmonary Hypertension": {
    nameAr: "ارتفاع ضغط الدم الرئوي",
    description: "High blood pressure in the arteries to your lungs",
    descriptionAr: "ارتفاع ضغط الدم في الشرايين المؤدية إلى الرئتين",
    severity: "high",                    // شدة عالية
    category: "Vascular Disease",        // فئة: مرض وعائي
    relatedSymptoms: [
      "Shortness of Breath",            // ضيق التنفس
      "Fatigue",                        // تعب
      "Dizziness",                      // دوخة
      "Chest Pain",                     // ألم الصدر
      "Swelling in Legs",               // تورم في الساقين
      "Cyanosis"                        // زرقة (تلون الجلد بالأزرق)
    ]
  },

  "Deep Vein Thrombosis (DVT)": {
    nameAr: "تجلط الأوردة العميقة",
    description: "Blood clot forms in a deep vein, usually in the legs",
    descriptionAr: "تشكل جلطة دموية في وريد عميق، عادة في الساقين",
    severity: "high",                    // شدة عالية
    category: "Vascular Disease",        // فئة: مرض وعائي
    relatedSymptoms: [
      "Leg Pain",                       // ألم الساق
      "Swelling in Legs",               // تورم في الساقين
      "Warmth over Area",               // دفء فوق المنطقة المصابة
      "Redness of Skin"                 // احمرار الجلد
    ]
  },

  "Aortic Aneurysm": {
    nameAr: "تمدد الأوعية الدموية الأبهري",
    description: "Abnormal bulge in the wall of the aorta",
    descriptionAr: "انتفاخ غير طبيعي في جدار الشريان الأبهري",
    severity: "critical",                // شدة حرجة
    category: "Vascular Disease",        // فئة: مرض وعائي
    relatedSymptoms: [
      "Chest Pain",                     // ألم الصدر
      "Back Pain",                      // ألم الظهر
      "Shortness of Breath",            // ضيق التنفس
      "Difficulty Swallowing"           // صعوبة البلع
    ]
  },

  /**
   * ================================
   * عيوب خلقية في القلب
   * Congenital Heart Defects
   * ================================
   */
  "Atrial Septal Defect (ASD)": {
    nameAr: "عيت الحاجز الأذيني",
    description: "Hole in the wall (septum) between the two upper chambers of your heart",
    descriptionAr: "ثقب في الجدار (الحاجز) بين الغرفتين العلويتين للقلب",
    severity: "moderate",                // شدة متوسطة
    category: "Congenital Heart Defect", // فئة: عيب خلقي في القلب
    relatedSymptoms: [
      "Shortness of Breath",            // ضيق التنفس
      "Fatigue",                        // تعب
      "Swelling in Legs",               // تورم في الساقين
      "Heart Murmur",                   // نفخة قلبية
      "Palpitations"                    // خفقان القلب
    ]
  }
};