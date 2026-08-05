# =====================================================================
# GuardianAI: Autonomous Data Steward for Snowflake
# Streamlit in Snowflake (SiS) app - Day 4
# 5 pages: Data Trust Overview | Findings Explorer | AI Investigation
#          | Remediation Center | Governance Log
#
# HOW TO DEPLOY (Snowsight):
#   1. Snowsight -> Projects -> Streamlit -> + Streamlit App
#   2. App location: database GUARDIANAI_DB, schema CORE, warehouse GUARDIANAI_WH
#   3. Paste this file, Run. (get_active_session() connects automatically.)
# =====================================================================

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="GuardianAI", page_icon="🛡️", layout="wide")
session = get_active_session()

# ---------------------------------------------------------------------
# Set the working context explicitly so every query resolves correctly,
# no matter how/where the app is deployed. This fixes errors like
# "Object 'DQ_HEALTH_SCORE' does not exist or not authorized".
# ---------------------------------------------------------------------
DB, SCHEMA, WH = "GUARDIANAI_DB", "CORE", "GUARDIANAI_WH"
try:
    session.sql(f"USE WAREHOUSE {WH}").collect()
except Exception:
    pass  # warehouse may already be attached to the app
session.sql(f"USE DATABASE {DB}").collect()
session.sql(f"USE SCHEMA {DB}.{SCHEMA}").collect()


# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------
@st.cache_data(ttl=60)
def q(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


def score_color(score: float) -> str:
    if score is None:
        return "gray"
    if score >= 90:
        return "#1a9850"   # green
    if score >= 75:
        return "#fee08b"   # yellow
    if score >= 50:
        return "#fc8d59"   # orange
    return "#d73027"       # red


def risk_badge(risk: str) -> str:
    colors = {"LOW": "#1a9850", "MEDIUM": "#fee08b",
              "HIGH": "#fc8d59", "CRITICAL": "#d73027"}
    c = colors.get(risk, "gray")
    return f"<span style='background:{c};color:white;padding:2px 10px;border-radius:10px;font-size:0.8em'>{risk}</span>"


# ---------------------------------------------------------------------
# Sidebar navigation
# ---------------------------------------------------------------------
st.sidebar.title("🛡️ GuardianAI")
st.sidebar.caption("Autonomous Data Steward for Snowflake")
page = st.sidebar.radio(
    "Navigate",
    ["📊 Data Trust Overview",
     "🔍 Findings Explorer",
     "🧠 AI Investigation Center",
     "🛠️ Remediation Center",
     "📜 Governance Log"],
)
st.sidebar.divider()
st.sidebar.info("Detect → Explain → Impact → Recommend → Approve → Execute → Validate")


# =====================================================================
# PAGE 1 - DATA TRUST OVERVIEW
# =====================================================================
if page.startswith("📊"):
    st.title("📊 Data Trust Overview")

    # Executive summary paragraph (from the Exec Summary Agent)
    try:
        summ = q("SELECT SUMMARY_TEXT FROM DQ_EXEC_SUMMARY ORDER BY GENERATED_AT DESC LIMIT 1")
        if not summ.empty:
            st.info(summ.iloc[0]["SUMMARY_TEXT"])
    except Exception:
        st.caption("Run 09_executive_summary.sql to populate the executive summary.")

    scores = q("SELECT TABLE_NAME, HEALTH_SCORE, BUSINESS_RISK FROM DQ_HEALTH_SCORE")
    overall = scores[scores.TABLE_NAME == "OVERALL"]
    tables = scores[scores.TABLE_NAME != "OVERALL"].sort_values("TABLE_NAME")

    # Headline tiles
    c1, c2, c3, c4 = st.columns(4)
    if not overall.empty:
        s = int(overall.iloc[0]["HEALTH_SCORE"])
        c1.markdown(f"<h1 style='color:{score_color(s)}'>{s}<span style='font-size:0.4em'>/100</span></h1>"
                    f"<b>Overall Trust Score</b>", unsafe_allow_html=True)
    try:
        openi = q("SELECT COUNT(*) N FROM DQ_ISSUES WHERE STATUS='OPEN'").iloc[0]["N"]
        crit = q("SELECT COUNT(*) N FROM DQ_ISSUES WHERE STATUS='OPEN' AND SEVERITY='CRITICAL'").iloc[0]["N"]
    except Exception:
        openi, crit = 0, 0
    c2.metric("Open Issues", int(openi))
    c3.metric("Critical Issues", int(crit))
    if not overall.empty:
        c4.markdown("<br>" + risk_badge(overall.iloc[0]["BUSINESS_RISK"]), unsafe_allow_html=True)

    st.divider()

    # Per-table score bars
    st.subheader("Health by table")
    for _, r in tables.iterrows():
        s = int(r["HEALTH_SCORE"])
        st.markdown(f"**{r['TABLE_NAME']}** &nbsp; {risk_badge(r['BUSINESS_RISK'])}",
                    unsafe_allow_html=True)
        st.progress(s / 100, text=f"{s}/100")

    # Before / after (if remediation history exists)
    try:
        hist = q("""
            SELECT COALESCE(b.TABLE_NAME,a.TABLE_NAME) TABLE_NAME,
                   b.HEALTH_SCORE BEFORE_SCORE, a.HEALTH_SCORE AFTER_SCORE
            FROM (SELECT * FROM DQ_HEALTH_HISTORY WHERE RUN_LABEL='BEFORE_REMEDIATION') b
            FULL JOIN (SELECT * FROM DQ_HEALTH_HISTORY WHERE RUN_LABEL='AFTER_REMEDIATION') a
              ON b.TABLE_NAME=a.TABLE_NAME
        """)
        if not hist.empty:
            st.divider()
            st.subheader("Before → After remediation")
            st.bar_chart(hist.set_index("TABLE_NAME")[["BEFORE_SCORE", "AFTER_SCORE"]])
    except Exception:
        pass


# =====================================================================
# PAGE 2 - FINDINGS EXPLORER
# =====================================================================
elif page.startswith("🔍"):
    st.title("🔍 Findings Explorer")
    st.caption("Every issue the Data Observer Agent detected (deterministic SQL).")

    issues = q("""SELECT TABLE_NAME, ISSUE_TYPE, SEVERITY, AFFECTED_ROWS, STATUS
                  FROM DQ_ISSUES ORDER BY
                  CASE SEVERITY WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
                                WHEN 'MEDIUM' THEN 3 ELSE 4 END""")
    colf1, colf2 = st.columns(2)
    tsel = colf1.multiselect("Table", sorted(issues.TABLE_NAME.unique()),
                             default=list(issues.TABLE_NAME.unique()))
    ssel = colf2.multiselect("Severity", ["CRITICAL", "HIGH", "MEDIUM", "LOW"],
                             default=["CRITICAL", "HIGH", "MEDIUM", "LOW"])
    f = issues[issues.TABLE_NAME.isin(tsel) & issues.SEVERITY.isin(ssel)]

    m1, m2, m3 = st.columns(3)
    m1.metric("Issues shown", len(f))
    m2.metric("Rows affected", int(f["AFFECTED_ROWS"].sum()) if not f.empty else 0)
    m3.metric("Critical", int((f.SEVERITY == "CRITICAL").sum()))
    st.dataframe(f, use_container_width=True, hide_index=True)


# =====================================================================
# PAGE 3 - AI INVESTIGATION CENTER
# =====================================================================
elif page.startswith("🧠"):
    st.title("🧠 AI Investigation Center")
    st.caption("Root cause + business impact generated by the Cortex agents.")

    a = q("""SELECT TABLE_NAME, ISSUE_TYPE, SEVERITY, IMPACT_LEVEL,
                    AFFECTED_ROWS, ROOT_CAUSE, BUSINESS_IMPACT
             FROM DQ_ISSUE_ANALYSIS
             ORDER BY CASE SEVERITY WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
                                    WHEN 'MEDIUM' THEN 3 ELSE 4 END""")
    if a.empty:
        st.warning("No analysis yet. Run files 07 & 08 (or fallback 10).")
    else:
        for _, r in a.iterrows():
            with st.expander(
                f"{r['SEVERITY']}  •  {r['TABLE_NAME']}  •  {r['ISSUE_TYPE']}  "
                f"({int(r['AFFECTED_ROWS'])} rows)"):
                st.markdown(f"**🔎 Root cause**  \n{r['ROOT_CAUSE']}")
                st.markdown(f"**💼 Business impact**  \n{r['BUSINESS_IMPACT']}")
                st.markdown(f"Impact level: {risk_badge(r['IMPACT_LEVEL'])}",
                            unsafe_allow_html=True)


# =====================================================================
# PAGE 4 - REMEDIATION CENTER
# =====================================================================
elif page.startswith("🛠️"):
    st.title("🛠️ Remediation Center")
    st.caption("Human-in-the-loop approval. AI advises, SQL executes, you approve.")

    p = q("""SELECT TABLE_NAME, ISSUE_TYPE, FIX_METHOD, CONFIDENCE, RISK_LEVEL,
                    REQUIRES_APPROVAL, APPROVAL_STATUS, EXECUTED,
                    RECOMMENDED_ACTION, FIX_SQL
             FROM DQ_REMEDIATION_PLAN
             ORDER BY CASE FIX_METHOD WHEN 'QUARANTINE' THEN 1
                                      WHEN 'DEDUP' THEN 2 ELSE 3 END,
                      CONFIDENCE DESC""")
    if p.empty:
        st.warning("No remediation plan yet. Run file 12.")
    else:
        m1, m2, m3, m4 = st.columns(4)
        m1.metric("Planned fixes", len(p))
        m2.metric("Approved", int((p.APPROVAL_STATUS == "APPROVED").sum()))
        m3.metric("Executed", int(p.EXECUTED.sum()))
        m4.metric("Need review", int(p.REQUIRES_APPROVAL.sum()))
        st.divider()
        for _, r in p.iterrows():
            status = "✅" if r["EXECUTED"] else ("👍" if r["APPROVAL_STATUS"] == "APPROVED" else "⏳")
            with st.expander(f"{status}  {r['TABLE_NAME']} • {r['ISSUE_TYPE']} • "
                             f"{r['FIX_METHOD']} • conf {int(r['CONFIDENCE'])}% • "
                             f"risk {r['RISK_LEVEL']}"):
                st.markdown(f"**Recommendation:** {r['RECOMMENDED_ACTION']}")
                st.code(r["FIX_SQL"], language="sql")
                st.caption(f"Approval: {r['APPROVAL_STATUS']} • "
                           f"Requires human review: {bool(r['REQUIRES_APPROVAL'])}")


# =====================================================================
# PAGE 5 - GOVERNANCE LOG
# =====================================================================
elif page.startswith("📜"):
    st.title("📜 Governance Log")
    st.caption("Immutable audit trail of every agent action (Responsible AI).")

    try:
        g = q("""SELECT EVENT_TIME, AGENT, ACTION, TABLE_NAME, ISSUE_TYPE, DETAIL, ACTOR
                 FROM DQ_GOVERNANCE_LOG ORDER BY EVENT_TIME DESC, AGENT""")
    except Exception:
        g = pd.DataFrame()

    if g.empty:
        st.warning("No governance log yet. Run file 15.")
    else:
        agents = sorted(g.AGENT.unique())
        sel = st.multiselect("Filter by agent", agents, default=agents)
        gf = g[g.AGENT.isin(sel)]
        c1, c2, c3 = st.columns(3)
        c1.metric("Total events", len(gf))
        c2.metric("Human-actor events", int((gf.ACTOR != "SYSTEM").sum()))
        c3.metric("Agents involved", gf.AGENT.nunique())
        st.dataframe(gf, use_container_width=True, hide_index=True)

st.sidebar.divider()
st.sidebar.caption("GuardianAI • CoCoQuest 2026")
