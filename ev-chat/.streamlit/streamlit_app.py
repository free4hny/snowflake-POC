import os
import json
import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="EV Analytics Chat", page_icon="💬", layout="wide")

st.title("💬 EV Population Analytics — Ask in Natural Language")
st.caption("Powered by Cortex Analyst + Semantic Model on Gold Layer")

session = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL")).session()

SEMANTIC_VIEW_FQN = "EV_POPULATION_DB.GOLD.EV_ANALYTICS_SV"

SUGGESTIONS = {
    "📈 YoY growth trend": "What is the YoY growth trend in EV registrations?",
    "🗺️ Top regions": "Which regions have the highest EV adoption rates?",
    "🏭 Tesla vs others": "Compare Tesla vs other manufacturers in market share",
    "⚡ BEV vs PHEV": "What is our market penetration by vehicle type BEV vs PHEV?",
    "💰 CAFV eligible": "What percentage of EVs are eligible for CAFV incentives?",
    "🔌 Charging stations": "How many charging stations are available by network?",
}

if "messages" not in st.session_state:
    st.session_state.messages = []

for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        if msg.get("sql"):
            st.code(msg["sql"], language="sql")
        if msg.get("df") is not None:
            st.dataframe(msg["df"], use_container_width=True)
        if msg.get("content"):
            st.write(msg["content"])

if not st.session_state.messages:
    selected = st.pills("Try asking:", list(SUGGESTIONS.keys()), label_visibility="collapsed")
    if selected:
        prompt = SUGGESTIONS[selected]
        st.session_state.messages.append({"role": "user", "content": prompt})
        st.rerun()


def call_cortex_analyst(question: str) -> dict:
    request_body = {
        "messages": [{"role": "user", "content": [{"type": "text", "text": question}]}],
        "semantic_model": SEMANTIC_VIEW_FQN,
    }
    resp = session.sql(
        "SELECT SNOWFLAKE.CORTEX.ANALYST(PARSE_JSON(?))",
        params=[json.dumps(request_body)]
    ).collect()
    return json.loads(resp[0][0])


if prompt := st.chat_input("Ask about EV population data..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.write(prompt)

    with st.chat_message("assistant"):
        with st.spinner("Analyzing..."):
            try:
                result = call_cortex_analyst(prompt)

                text_content = ""
                sql_content = ""
                df = None

                for item in result.get("message", {}).get("content", []):
                    if item["type"] == "text":
                        text_content = item["text"]
                    elif item["type"] == "sql":
                        sql_content = item["statement"]

                if text_content:
                    st.write(text_content)
                if sql_content:
                    st.code(sql_content, language="sql")
                    df = session.sql(sql_content).to_pandas()
                    st.dataframe(df, use_container_width=True)

                    if len(df.columns) >= 2 and df.select_dtypes(include="number").shape[1] >= 1:
                        st.bar_chart(df.set_index(df.columns[0]))

                st.session_state.messages.append({
                    "role": "assistant",
                    "content": text_content,
                    "sql": sql_content,
                    "df": df,
                })

            except Exception as e:
                error_msg = f"Error: {str(e)}"
                st.error(error_msg)
                st.session_state.messages.append({"role": "assistant", "content": error_msg})
