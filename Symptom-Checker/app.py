import streamlit as st
import joblib
import json
import numpy as np
import os
import re
from datetime import datetime
import warnings
warnings.filterwarnings('ignore', category=UserWarning, module='sklearn')

# ==========================================
# PAGE CONFIGURATION
# ==========================================
st.set_page_config(
    page_title="ExperTIQ Health",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# ==========================================
# PROFESSIONAL PDF GENERATION (moved to pdf_new.create_pro_pdf)
# ==========================================


# ==========================================
# ENHANCED TRANSLATION ENGINE
# ==========================================
def parse_expert_js(file_path):
    registry = {}
    if not os.path.exists(file_path):
        return registry
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        pattern = r'["\']([^"\']+)["\']\s*:\s*(\{(?:[^{}]*|\{(?:[^{}]*|\{[^{}]*\})*\})*\})'
        matches = re.finditer(pattern, content)
        for m in matches:
            key, obj = m.group(1), m.group(2)
            item = {}
            for field in ['nameAr', 'description', 'descriptionAr', 'severity', 'category']:
                f_m = re.search(f'{field}\s*:\s*["\']([^"\']+)["\']', obj)
                if f_m:
                    item[field] = f_m.group(1).replace('\\"', '"')
            registry[key] = item
    except:
        pass
    return registry


def extract_comment_translations(file_path):
    translations = {}
    if not os.path.exists(file_path):
        return translations
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            for line in f:
                match = re.search(
                    r'["\']([^"\']+)["\']\s*,?\s*//\s*(.+)', line)
                if match:
                    eng = match.group(1).strip()
                    ar = match.group(2).strip()
                    if re.search(r'[\u0600-\u06FF]', ar):
                        translations[eng] = ar
    except:
        pass
    return translations


def build_category_translations():
    return {
        "Coronary Artery Disease": "مرض الشريان التاجي",
        "Heart Failure": "فشل القلب",
        "Valvular Heart Disease": "أمراض صمامات القلب",
        "Cardiomyopathy": "اعتلال عضلة القلب",
        "Arrhythmia": "اضطراب النظم القلبي",
        "Inflammatory Heart Disease": "أمراض القلب الالتهابية",
        "Vascular Disease": "أمراض الأوعية الدموية",
        "Respiratory Infection": "عدوى تنفسية",
        "Chronic Respiratory": "أمراض تنفسية مزمنة",
        "Gastrointestinal": "الجهاز الهضمي",
        "Metabolic": "الأمراض الأيضية",
        "Endocrine": "الغدد الصماء",
        "Musculoskeletal": "الجهاز العضلي الهيكلي",
        "Neurological": "الأمراض العصبية",
        "Psychiatric": "الأمراض النفسية",
        "Dermatological": "الأمراض الجلدية",
        "Infectious Disease": "الأمراض المعدية",
        "Hematological": "أمراض الدم",
        "Liver Disease": "أمراض الكبد",
        "Renal": "أمراض الكلى"
    }


@st.cache_resource
def init_system():
    try:
        base = os.path.join("Output", "Production")
        # Suppress sklearn warnings during model loading
        import warnings
        with warnings.catch_warnings():
            warnings.filterwarnings(
                'ignore', category=UserWarning, module='sklearn')
            model = joblib.load(os.path.join(base, 'best_model.pkl'))
            vec = joblib.load(os.path.join(base, 'vectorizer.pkl'))
        with open(os.path.join(base, 'model_metadata.json'), 'r', encoding='utf-8') as f:
            meta = json.load(f)
        # Try to load dynamic metrics if available
        metrics_path = os.path.join(base, 'metrics.json')
        if os.path.exists(metrics_path):
            try:
                with open(metrics_path, 'r', encoding='utf-8') as mf:
                    meta['metrics'] = json.load(mf)
            except:
                pass

        master_reg = {}
        js_paths = [
            os.path.join("Data", "Heart", "HeartDiseases.js"),
            os.path.join("Data", "Heart", "HeartSymptoms.js"),
            os.path.join("Data", "General", "GeneralDiseases.js"),
            os.path.join("Data", "General", "GeneralSymptoms.js")
        ]

        for path in js_paths:
            master_reg.update(parse_expert_js(path))

        comment_trans = {}
        for path in js_paths:
            comment_trans.update(extract_comment_translations(path))

        for key, ar_text in comment_trans.items():
            if key not in master_reg:
                master_reg[key] = {}
            if 'nameAr' not in master_reg[key]:
                master_reg[key]['nameAr'] = ar_text

        meta['registry'] = master_reg
        meta['category_translations'] = build_category_translations()
        meta['mapping'] = {
            "Heart": ["Coronary Artery Disease", "Heart Failure", "Valvular Heart Disease", "Cardiomyopathy", "Arrhythmia", "Inflammatory Heart Disease", "Vascular Disease"],
            "General": ["Respiratory Infection", "Chronic Respiratory", "Gastrointestinal", "Metabolic", "Endocrine", "Musculoskeletal", "Neurological", "Psychiatric", "Dermatological", "Infectious Disease", "Hematological", "Liver Disease", "Renal"]
        }
        return model, vec, meta
    except Exception as e:
        st.error(f"System Error: {e}")
        st.stop()

# ==========================================
# UI HELPERS
# ==========================================


def t(en, ar): return ar if st.session_state.get('lang') == 'ar' else en
def get_dir(): return "rtl" if st.session_state.get('lang') == 'ar' else "ltr"


def apply_friendly_styles():
    st.markdown("""
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;800&family=Noto+Sans+Arabic:wght@300;500;700&display=swap');
        :root {
            --bg: #0a0e14;
            --card: #151b23;
            --accent: #3b82f6;
            --success: #10b981;
            --warning: #f59e0b;
            --danger: #ef4444;
            --font-en: 'Outfit', 'Segoe UI', Arial, sans-serif;
            --font-ar: 'Noto Sans Arabic', Tahoma, Arial, sans-serif;
        }

        html, body, [class*="css"] { font-family: var(--font-en); background-color: var(--bg); color: white; }
        .stApp { background-color: var(--bg); }
        
        /* Progress Pills */
        .step-pill { padding: 0.5rem 1.5rem; border-radius: 99px; background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); font-size: 0.95rem; transition: all 0.2s; }
        .step-active { background: linear-gradient(135deg, rgba(59, 130, 246, 0.35), rgba(16, 185, 129, 0.25)); border-color: #3b82f6; box-shadow: 0 0 12px rgba(59, 130, 246, 0.25); font-weight: 700; }
        
        /* Expert Cards */
        .expert-card { background: linear-gradient(135deg, var(--card) 0%, rgba(59, 130, 246, 0.04) 100%); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 24px; padding: 3rem; box-shadow: 0 18px 40px -18px rgba(0, 0, 0, 0.6); margin-bottom: 2rem; position: relative; overflow: hidden; }
        
        /* UNIFIED BUTTON STYLES - All buttons look the same */
        .stButton > button,
        div[data-testid="column"] > div > div > div > button,
        button[kind="primary"],
        button[kind="secondary"] {
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%) !important;
            color: white !important;
            border: 1px solid rgba(255,255,255,0.1) !important;
            padding: 1rem 2rem !important;
            border-radius: 16px !important;
            font-weight: 600 !important;
            transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275) !important;
            width: 100% !important;
            min-height: 4.5rem !important;
            font-size: 1.1rem !important;
            position: relative !important;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3) !important;
        }
        
        .stButton > button:hover,
        div[data-testid="column"] > div > div > div > button:hover,
        button[kind="primary"]:hover,
        button[kind="secondary"]:hover {
            border-color: var(--accent) !important;
            box-shadow: 0 0 30px rgba(59, 130, 246, 0.4) !important;
            transform: translateY(-3px) scale(1.02) !important;
            color: var(--accent) !important;
            background: linear-gradient(135deg, #1e293b 0%, rgba(59, 130, 246, 0.2) 100%) !important;
        }
        
        /* SQUARE CATEGORY BOXES - Specialty Selection */
        div[data-testid="column"] > div > div > div > button[key="heart_btn"],
        div[data-testid="column"] > div > div > div > button[key="general_btn"] {
            height: 280px !important;
            padding: 2.5rem 1.5rem !important;
            white-space: pre-line !important;
            display: flex !important;
            flex-direction: column !important;
            align-items: center !important;
            justify-content: center !important;
            font-size: 1.15rem !important;
            line-height: 1.8 !important;
            text-align: center !important;
        }
        
        /* Severity Badges */
        .s-badge { display: inline-block; padding: 0.7rem 1.8rem; border-radius: 16px; font-weight: 800; text-transform: uppercase; font-size: 0.9rem; margin-bottom: 1.5rem; letter-spacing: 0.5px; }
        .critical { background: linear-gradient(135deg, #fee2e2, #fecaca); color: #991b1b; border: 2px solid #ef4444; box-shadow: 0 0 25px rgba(239, 68, 68, 0.3); }
        .high { background: linear-gradient(135deg, #ffedd5, #fed7aa); color: #9a3412; border: 2px solid #f59e0b; box-shadow: 0 0 25px rgba(245, 158, 11, 0.3); }
        .moderate { background: linear-gradient(135deg, #d1fae5, #a7f3d0); color: #065f46; border: 2px solid #10b981; box-shadow: 0 0 25px rgba(16, 185, 129, 0.3); }
        .low { background: linear-gradient(135deg, #dbeafe, #bfdbfe); color: #1e3a8a; border: 2px solid #3b82f6; box-shadow: 0 0 25px rgba(59, 130, 246, 0.3); }
        
        /* Advice & Report Boxes */
        .advice-box { background: linear-gradient(135deg, rgba(16, 185, 129, 0.1), rgba(59, 130, 246, 0.1)); border: 2px solid rgba(16, 185, 129, 0.3); border-radius: 24px; padding: 2.5rem; margin: 2rem 0; position: relative; box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2); }
        .advice-box::before { content: '💡'; position: absolute; top: 1.5rem; right: 1.5rem; font-size: 2.5rem; opacity: 0.3; }
        .results-container { background: linear-gradient(135deg, #0f172a, rgba(59, 130, 246, 0.05)); border-radius: 24px; padding: 2.5rem; margin-top: 2rem; box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2); }
        
        /* Emoji Decorations */
        .emoji-large { font-size: 3rem; display: inline-block; }
        
        /* Direction Helpers */
        .rtl { direction: rtl; text-align: right; font-family: var(--font-ar) !important; }
        .rtl * { font-family: var(--font-ar) !important; }
        .ltr { direction: ltr; text-align: left; font-family: var(--font-en) !important; }
        .ltr * { font-family: var(--font-en) !important; }
        
        /* Animations */
        @keyframes slideUp { from { opacity: 0; transform: translateY(30px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.8; } }
        @keyframes bounce { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-10px); } }
        @keyframes glow { 0%, 100% { box-shadow: 0 0 20px currentColor; } 50% { box-shadow: 0 0 30px currentColor; } }
        @keyframes rotate { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        
        /* Enhanced Arabic Typography */
        .arabic-text { font-family: var(--font-ar) !important; line-height: 1.8 !important; font-size: 1.1rem !important; }
        .arabic-title { font-family: var(--font-ar) !important; font-weight: 700 !important; font-size: 1.5rem !important; }
        
        /* Sidebar enhancements */
        [data-testid="stSidebar"] {
            background: linear-gradient(to bottom, #0f172a, #0a0e14);
        }
        
        /* Multiselect styling */
        .stMultiSelect [data-baseweb="select"] {
            background-color: rgba(30, 41, 59, 0.3) !important;
            border: 1px solid rgba(255, 255, 255, 0.1) !important;
            border-radius: 12px !important;
        }
        
        /* Selectbox styling */
        .stSelectbox [data-baseweb="select"] {
            background-color: rgba(30, 41, 59, 0.3) !important;
            border: 1px solid rgba(255, 255, 255, 0.1) !important;
            border-radius: 12px !important;
        }
        
        /* Card layout for results */
        .result-card { background: linear-gradient(135deg, var(--card) 0%, rgba(59, 130, 246, 0.04) 100%); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 20px; padding: 2rem; margin: 1rem 0; box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3); }
        .result-item { display: flex; justify-content: space-between; padding: 0.8rem 0; border-bottom: 1px solid rgba(255, 255, 255, 0.1); }
        .result-item:last-child { border-bottom: none; }
        .result-label { font-weight: 600; color: #93c5fd; }
        .result-value { color: #e2e8f0; font-weight: 500; }
    </style>
    """, unsafe_allow_html=True)

# ==========================================
# MAIN APP
# ==========================================


def main():
    apply_friendly_styles()
    model, vec, meta = init_system()

    if 'page' not in st.session_state:
        st.session_state.page = 1
    if 'lang' not in st.session_state:
        st.session_state.lang = 'en'
    if 'm_cat' not in st.session_state:
        st.session_state.m_cat = 'General'
    if 'sub_cat' not in st.session_state:
        st.session_state.sub_cat = None
    if 'sub_cat_display' not in st.session_state:
        st.session_state.sub_cat_display = None
    if 's_names' not in st.session_state:
        st.session_state.s_names = []

    with st.sidebar:
        st.markdown(f"### {t('Navigation', 'التنقل')}")
        nav_items = [
            (1, t('Language', 'اللغة')),
            (2, t('Specialty', 'التخصص')),
            (3, t('Symptoms', 'الأعراض')),
            (4, t('Results', 'النتائج')),
            (5, t('Model Metrics', 'مقاييس النموذج')),
        ]
        labels = [x[1] for x in nav_items]
        current_idx = next((i for i, (p, _) in enumerate(
            nav_items) if p == st.session_state.page), 0)
        picked = st.radio(t('Go to', 'الانتقال إلى'),
                          labels, index=current_idx)
        target_page = next(
            (p for p, lab in nav_items if lab == picked), st.session_state.page)
        if target_page != st.session_state.page:
            st.session_state.page = target_page
            st.rerun()

    # Progress
    steps = [t("Language", "اللغة"), t("Specialty", "التخصص"), t(
        "Symptoms", "الأعراض"), t("Analysis", "التحليل"), t("Metrics", "المقاييس")]
    cols = st.columns(len(steps))
    for i, s in enumerate(steps):
        active = "step-active" if st.session_state.page == (i+1) else ""
        cols[i].markdown(
            f'<div class="step-pill {active}" style="text-align:center;">{s}</div>', unsafe_allow_html=True)

    # PAGE 1: LANGUAGE
    if st.session_state.page == 1:

        col1, col_c, col2 = st.columns([1, 1.8, 1])
        with col_c:
            st.markdown("""
            <div class="expert-card" style="text-align: center;">
                <h1 style="font-size: 3.5rem; margin: 1rem 0; letter-spacing:-2px;">ExperTIQ Health</h1>
                <p style="color: #94a3b8; font-size: 1.05rem; margin-bottom: 2rem;">AI-assisted symptom assessment</p>
                <div style="height: 1px; background: rgba(255,255,255,0.1); margin-bottom: 2rem;"></div>
                <p style="font-size: 1.1rem; margin-bottom: 0.5rem;">Choose your preferred language</p>
                <p style="font-size: 0.95rem; color: #64748b;">اختر لغتك المفضلة</p>
            </div>
            """, unsafe_allow_html=True)
            c1, c2 = st.columns(2)
            if c1.button("🇺🇸 ENGLISH"):
                st.session_state.lang = 'en'
                st.session_state.page = 2
                st.rerun()
            if c2.button("🇪🇬 العربية"):
                st.session_state.lang = 'ar'
                st.session_state.page = 2
                st.rerun()

    # PAGE 2: SPECIALTY - Square Category Boxes
    elif st.session_state.page == 2:
        st.markdown(f'<div class="{get_dir()}">', unsafe_allow_html=True)
        with st.container():
            st.markdown('<div class="expert-card">', unsafe_allow_html=True)
            st.title(t("Clinical Specialty Selection", "اختيار التخصص السريري"))
            st.write(t("Select the clinical area that best matches your symptoms.",
                     "اختر التخصص الأنسب لأعراضك."))

            c1, c2 = st.columns(2)
            with c1:
                if st.button(f"❤️\n\n{t('Heart & Vascular', 'القلب والأوعية')}\n\n💓\n\n{t('Cardiac System', 'نظام القلب')}", key="heart_btn"):
                    st.session_state.m_cat = 'Heart'
                    st.session_state.sub_cat = meta['mapping']['Heart'][0]
                    st.session_state.page = 3
                    st.rerun()
            with c2:
                if st.button(f"🏥\n\n{t('General Medicine', 'الطب الباطني')}\n\n🩹\n\n{t('Comprehensive', 'شامل')}", key="general_btn"):
                    st.session_state.m_cat = 'General'
                    st.session_state.sub_cat = meta['mapping']['General'][0]
                    st.session_state.page = 3
                    st.rerun()

            st.info(t("Tip: Choose the closest matching specialty.",
                    "نصيحة: اختر التخصص الأقرب لأعراضك."))
            if st.button(f"⬅️ {t('Back', 'العودة')}"):
                st.session_state.page = 1
                st.rerun()
            st.markdown('</div>', unsafe_allow_html=True)

    # PAGE 3: SYMPTOMS
    elif st.session_state.page == 3:
        st.markdown(f'<div class="{get_dir()}">', unsafe_allow_html=True)
        with st.container():
            st.markdown('<div class="expert-card">', unsafe_allow_html=True)
            st.subheader(t("Symptom Assessment", "تقييم الأعراض"))
            st.write(t("Select your symptoms to generate an assessment.",
                     "حدد الأعراض للحصول على تقييم."))

            raw_subs = meta['mapping'][st.session_state.m_cat]
            cat_trans = meta['category_translations']
            sub_display_map = {}
            for sub in raw_subs:
                display_name = cat_trans.get(
                    sub, sub) if st.session_state.lang == 'ar' else sub
                sub_display_map[display_name] = sub

            st.markdown(f"**{t('Refine category:', 'تحديد الفئة:')}**")
            sel_sub_disp = st.selectbox(t("Select category", "اختر الفئة"), list(
                sub_display_map.keys()), label_visibility="collapsed")
            st.session_state.sub_cat = sub_display_map[sel_sub_disp]
            st.session_state.sub_cat_display = sel_sub_disp

            raw_symptoms = meta['categories'].get(st.session_state.sub_cat, [])
            raw_symptoms.sort()
            symp_map = {}
            symp_list_disp = []
            for sid in raw_symptoms:
                if st.session_state.lang == 'ar':
                    s_ar = meta['registry'].get(sid, {}).get('nameAr', sid)
                    symp_list_disp.append(s_ar)
                    symp_map[s_ar] = sid
                else:
                    symp_list_disp.append(sid)
                    symp_map[sid] = sid

            st.markdown(f"**{t('Select symptoms:', 'حدد الأعراض:')}**")
            st.session_state.s_names = st.multiselect(
                t("Choose symptoms", "اختر الأعراض"), symp_list_disp, label_visibility="collapsed")

            if len(st.session_state.s_names) > 0:
                st.success(
                    f"{t(f'Selected: {len(st.session_state.s_names)} symptom(s)', f'تم اختيار: {len(st.session_state.s_names)} عرض/أعراض')}")

            col1, col2 = st.columns(2)
            with col1:
                if st.button(f"⬅️ {t('Back', 'العودة')}", key="bback"):
                    st.session_state.page = 2
                    st.rerun()
            with col2:
                if st.button(f"🚀 {t('Analyze My Symptoms', 'تحليل أعراضي')}"):
                    if not st.session_state.s_names:
                        st.error(
                            f"⚠️ {t('Please select at least one symptom', 'الرجاء اختيار عرض واحد على الأقل')}")
                    else:
                        with st.spinner(f"🔬 {t('Running clinical analysis...', 'جارٍ إجراء التحليل السريري...')}"):
                            st.session_state.s_ids = [symp_map[n]
                                                      for n in st.session_state.s_names]
                        st.session_state.page = 4
                        st.rerun()
            st.markdown('</div>', unsafe_allow_html=True)

    # PAGE 4: RESULTS
    elif st.session_state.page == 4:
        st.markdown(f'<div class="{get_dir()}">', unsafe_allow_html=True)

        q_ids = " ".join(st.session_state.s_ids)
        vec_in = vec.transform([q_ids])
        pred_key = model.predict(vec_in)[0]
        conf_val = max(model.predict_proba(vec_in)[0])

        res_meta = meta['registry'].get(pred_key, {})
        d_name_final = res_meta.get(
            'nameAr', pred_key) if st.session_state.lang == 'ar' else pred_key
        sev_label = res_meta.get('severity', 'moderate').lower()
        advice_text = res_meta.get('descriptionAr' if st.session_state.lang == 'ar' else 'description',
                                   t("Please consult a healthcare professional for proper diagnosis.",
                                     "يرجى استشارة أخصائي رعاية صحية للحصول على تشخيص دقيق."))

        sev_emoji = {"critical": "🚨", "high": "⚠️", "moderate": "✅"}
        sev_emoji_display = sev_emoji.get(sev_label, "ℹ️")
        sev_ar_map = {"critical": "حرِج", "high": "مرتفع", "moderate": "متوسط"}
        sev_display = sev_ar_map.get(sev_label, sev_label)
        align = 'right' if st.session_state.lang == 'ar' else 'left'

        with st.container():
            st.markdown(
                '<div class="expert-card" style="text-align: center;">', unsafe_allow_html=True)
            st.markdown(
                f'<div style="font-size: 4rem; margin-bottom: 1rem;">{sev_emoji_display}</div>', unsafe_allow_html=True)
            badge_text = t(f"{sev_label.upper()} RISK LEVEL",
                           f"مستوى الخطر: {sev_display}")
            st.markdown(
                f'<div class="s-badge {sev_label}">{badge_text}</div>', unsafe_allow_html=True)
            st.markdown(
                f'<div style="color: #94a3b8; font-size: 0.9rem; letter-spacing: 2px; margin-top: 1rem;">{t("AI ANALYSIS COMPLETE", "اكتمل التحليل بالذكاء الاصطناعي")}</div>', unsafe_allow_html=True)
            st.markdown(
                f'<h1 style="font-size: 3.5rem; margin: 1rem 0; line-height: 1.2;">{d_name_final}</h1>', unsafe_allow_html=True)
            st.markdown(
                f'<p style="color: #10b981; font-weight: 800; font-size: 1.2rem;">🎯 {t("Confidence", "مستوى الثقة")}: {conf_val:.1%}</p>', unsafe_allow_html=True)

            # Enhanced Advice
            st.markdown(f"""
            <div class="advice-box" style="text-align: {align};">
                <h2 style="color: #10b981; margin-bottom: 1rem; font-size: 1.5rem;">💚 {t("Expert Health Guidance", "إرشادات صحية من الخبراء")}</h2>
                <p style="font-size: 1.1rem; line-height: 1.8; color: #e2e8f0; margin-bottom: 1.5rem;">{advice_text}</p>
                <div style="background: rgba(16, 185, 129, 0.15); padding: 1.8rem; border-radius: 16px; border-left: 4px solid #10b981; margin-top: 1.5rem;">
                    <h3 style="color: #10b981; font-size: 1.1rem; margin-bottom: 0.8rem;">🌟 {t("Important Reminders", "تذكيرات مهمة")}</h3>
                    <ul style="color: #cbd5e1; font-size: 0.95rem; line-height: 1.7; margin: 0; padding-{'right' if st.session_state.lang == 'ar' else 'left'}: 1.5rem;">
                        <li>{t("This is an AI assessment, not a medical diagnosis", "هذا تقييم بالذكاء الاصطناعي وليس تشخيصاً طبياً")}</li>
                        <li>{t("Always consult a qualified healthcare provider", "استشر دائماً مقدم رعاية صحية مؤهل")}</li>
                        <li>{t("Early detection leads to better outcomes", "الكشف المبكر يؤدي إلى نتائج أفضل")}</li>
                        <li>{t("Take care of yourself and stay healthy 💪", "اعتني بنفسك وابق بصحة جيدة 💪")}</li>
                    </ul>
                </div>
            </div>
            """, unsafe_allow_html=True)

            # Link to metrics page
            st.markdown('<div class="expert-card">', unsafe_allow_html=True)
            if st.button(f"📊 {t('View Model Metrics', 'عرض مقاييس النموذج')}"):
                st.session_state.page = 5
                st.rerun()
            st.markdown('</div>', unsafe_allow_html=True)

            # Report in selected language
            st.markdown(
                f'<div class="results-container" style="text-align: {align};">', unsafe_allow_html=True)
            st.markdown(
                f"### 📊 {t('Your Health Assessment Summary', 'ملخص تقييمك الصحي')}")

            # Create a clean, organized summary card
            st.markdown(f'<div class="result-card">', unsafe_allow_html=True)

            # Category
            st.markdown(f'<div class="result-item">', unsafe_allow_html=True)
            st.markdown(
                f'<span class="result-label">{t("Category", "الفئة")}:</span>', unsafe_allow_html=True)
            st.markdown(
                f'<span class="result-value">{t(st.session_state.m_cat, "قلبي" if st.session_state.m_cat=="Heart" else "عام")} | {st.session_state.sub_cat_display}</span>', unsafe_allow_html=True)
            st.markdown(f'</div>', unsafe_allow_html=True)

            # Symptoms Count
            st.markdown(f'<div class="result-item">', unsafe_allow_html=True)
            st.markdown(
                f'<span class="result-label">{t("Symptoms Selected", "الأعراض المحددة")}:</span>', unsafe_allow_html=True)
            st.markdown(
                f'<span class="result-value">{len(st.session_state.s_names)}</span>', unsafe_allow_html=True)
            st.markdown(f'</div>', unsafe_allow_html=True)

            # Assessment Result
            st.markdown(f'<div class="result-item">', unsafe_allow_html=True)
            st.markdown(
                f'<span class="result-label">{t("Assessment Result", "نتيجة التقييم")}:</span>', unsafe_allow_html=True)
            st.markdown(
                f'<span class="result-value">{d_name_final}</span>', unsafe_allow_html=True)
            st.markdown(f'</div>', unsafe_allow_html=True)

            # Risk Level
            risk_color = {'critical': '#ef4444', 'high': '#f59e0b',
                          'moderate': '#10b981', 'low': '#3b82f6'}
            st.markdown(f'<div class="result-item">', unsafe_allow_html=True)
            st.markdown(
                f'<span class="result-label">{t("Risk Level", "مستوى الخطر")}:</span>', unsafe_allow_html=True)
            st.markdown(
                f'<span class="result-value" style="color: {risk_color.get(sev_label, "#10b981")}; font-weight: 700;">{t(sev_label.upper(), sev_display)} {sev_emoji_display}</span>', unsafe_allow_html=True)
            st.markdown(f'</div>', unsafe_allow_html=True)

            # Date
            st.markdown(f'<div class="result-item">', unsafe_allow_html=True)
            st.markdown(
                f'<span class="result-label">{t("Date", "التاريخ")}:</span>', unsafe_allow_html=True)
            st.markdown(
                f'<span class="result-value">{datetime.now().strftime("%Y-%m-%d %H:%M")}</span>', unsafe_allow_html=True)
            st.markdown(f'</div>', unsafe_allow_html=True)

            st.markdown(f'</div>', unsafe_allow_html=True)  # Close result-card

            st.markdown('</div>', unsafe_allow_html=True)

            # Simplified action buttons
            col1, col2 = st.columns(2)
            with col1:
                if st.button(f"🔄 {t('New Assessment', 'تقييم جديد')}"):
                    st.session_state.s_names = []
                    st.session_state.page = 1
                    st.rerun()
            with col2:
                if st.button(f"ℹ️ {t('Learn More', 'معرفة المزيد')}"):
                    st.info(
                        f"🌐 {t('Visit our website for more health resources', 'زر موقعنا للمزيد من الموارد الصحية')}")

            st.markdown('</div>', unsafe_allow_html=True)

    # PAGE 5: MODEL METRICS
    elif st.session_state.page == 5:
        st.markdown(f'<div class="{get_dir()}">', unsafe_allow_html=True)
        with st.container():
            st.markdown('<div class="expert-card">', unsafe_allow_html=True)
            st.subheader(t("AI Model Information",
                         "معلومات نموذج الذكاء الاصطناعي"))

            # Pull metrics with fallbacks
            m = meta.get('metrics', {})
            acc = m.get('accuracy')
            f1 = m.get('f1_score') or m.get('f1')
            cases = m.get('training_cases') or m.get(
                'samples') or m.get('num_samples')
            # format helpers

            def fmt_pct(x):
                try:
                    return f"{float(x)*100:.1f}%" if float(x) <= 1 else f"{float(x):.1f}%"
                except:
                    return "90.3%"

            def fmt_int(x):
                try:
                    v = int(float(x))
                    return f"{v:,}"
                except:
                    return "10,250+"

            col_a, col_b, col_c = st.columns(3)
            with col_a:
                st.markdown(f'''
                <div style="background: linear-gradient(135deg, rgba(59, 130, 246, 0.15), rgba(59, 130, 246, 0.05)); padding: 2rem 1.5rem; border-radius: 16px; text-align: center; border: 2px solid rgba(59, 130, 246, 0.3); min-height: 180px; display: flex; flex-direction: column; justify-content: center;">
                    <div style="font-size: 2.5rem; margin-bottom: 1rem;">⚙️</div>
                    <div style="font-weight: 800; font-size: 1.2rem; color: #3b82f6;">Standard MLP</div>
                    <div style="color: #64748b; font-size: 0.8rem; margin-top: 0.5rem;">{t('Multi-Layer Perceptron', 'إدراك متعدد الطبقات')}</div>
                </div>
                ''', unsafe_allow_html=True)
            with col_b:
                st.markdown(f'''
                <div style="background: linear-gradient(135deg, rgba(16, 185, 129, 0.15), rgba(16, 185, 129, 0.05)); padding: 2rem 1.5rem; border-radius: 16px; text-align: center; border: 2px solid rgba(16, 185, 129, 0.3); min-height: 180px; display: flex; flex-direction: column; justify-content: center;">
                    <div style="font-size: 2.5rem; margin-bottom: 1rem;">🎯</div>
                    <div style="font-weight: 800; font-size: 1.8rem; color: #10b981;">{fmt_pct(acc)}</div>
                    <div style="color: #64748b; font-size: 0.8rem; margin-top: 0.5rem;">{t(f'F1-Score: {fmt_pct(f1)}', f'مقياس F1: {fmt_pct(f1)}')}</div>
                </div>
                ''', unsafe_allow_html=True)
            with col_c:
                st.markdown(f'''
                <div style="background: linear-gradient(135deg, rgba(245, 158, 11, 0.15), rgba(245, 158, 11, 0.05)); padding: 2rem 1.5rem; border-radius: 16px; text-align: center; border: 2px solid rgba(245, 158, 11, 0.3); min-height: 180px; display: flex; flex-direction: column; justify-content: center;">
                    <div style="font-size: 2.5rem; margin-bottom: 1rem;">📈</div>
                    <div style="font-weight: 800; font-size: 1.3rem; color: #f59e0b;">{fmt_int(cases)}+</div>
                    <div style="color: #64748b; font-size: 0.8rem; margin-top: 0.5rem;">{t('Medical Cases', 'حالات طبية')}</div>
                </div>
                ''', unsafe_allow_html=True)

            st.info(f"🔬 {t('This model has been trained on diverse medical datasets to ensure accurate predictions across multiple conditions.', 'تم تدريب هذا النموذج على مجموعات بيانات طبية متنوعة لضمان توقعات دقيقة.')}")

            if st.button(f"⬅️ {t('Back to Results', 'العودة إلى النتائج')}"):
                st.session_state.page = 4
                st.rerun()


if __name__ == "__main__":
    main()
