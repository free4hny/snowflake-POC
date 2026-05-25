import os
import streamlit as st

st.set_page_config(page_title="EV Population Dashboard", page_icon="⚡", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))

st.title("⚡ EV Population Analytics Dashboard")
st.caption("Powered by Snowflake Medallion Architecture — Bronze → Silver → Gold")

@st.cache_data
def load_yoy_growth():
    return conn.query("""
        SELECT MODEL_YEAR, REGISTRATIONS, BEV_COUNT, PHEV_COUNT, YOY_GROWTH_PCT, AVG_RANGE
        FROM EV_POPULATION_DB.GOLD.AGG_EV_YOY_GROWTH
        ORDER BY MODEL_YEAR
    """)

@st.cache_data
def load_region_data():
    return conn.query("""
        SELECT STATE, COUNTY, CITY, TOTAL_EVS, BEV_COUNT, PHEV_COUNT, BEV_PERCENTAGE, CAFV_ELIGIBLE_PCT
        FROM EV_POPULATION_DB.GOLD.AGG_EV_BY_REGION
        ORDER BY TOTAL_EVS DESC
    """)

@st.cache_data
def load_make_model():
    return conn.query("""
        SELECT MAKE, MODEL, EV_TYPE_SHORT, TOTAL_REGISTRATIONS, MARKET_SHARE_PCT, AVG_RANGE
        FROM EV_POPULATION_DB.GOLD.AGG_EV_BY_MAKE_MODEL
        ORDER BY TOTAL_REGISTRATIONS DESC
    """)

@st.cache_data
def load_coverage():
    return conn.query("""
        SELECT CITY, STATE, TOTAL_EVS, CHARGING_STATIONS, EVS_PER_STATION, COVERAGE_STATUS
        FROM EV_POPULATION_DB.GOLD.AGG_EV_CHARGING_COVERAGE
        WHERE CHARGING_STATIONS > 0
        ORDER BY EVS_PER_STATION DESC
    """)

df_yoy = load_yoy_growth()
df_region = load_region_data()
df_make = load_make_model()
df_coverage = load_coverage()

col1, col2, col3, col4 = st.columns(4)
col1.metric("Total EVs", f"{df_region['TOTAL_EVS'].sum():,}")
col2.metric("BEV Share", f"{(df_yoy['BEV_COUNT'].sum() / df_yoy['REGISTRATIONS'].sum() * 100):.1f}%")
col3.metric("Peak YoY Growth", f"{df_yoy['YOY_GROWTH_PCT'].max():.0f}%")
col4.metric("Avg Range (miles)", f"{df_yoy['AVG_RANGE'].mean():.0f}")

st.divider()

tab1, tab2, tab3, tab4 = st.tabs([
    "📈 YoY Growth Trend",
    "🗺️ Regional Adoption",
    "🏭 Market Share",
    "🔌 Charging Coverage"
])

with tab1:
    st.subheader("Year-over-Year EV Registration Growth")
    st.bar_chart(df_yoy.set_index("MODEL_YEAR")[["BEV_COUNT", "PHEV_COUNT"]])
    st.line_chart(df_yoy.set_index("MODEL_YEAR")["YOY_GROWTH_PCT"])

with tab2:
    st.subheader("Top Regions by EV Adoption")
    st.dataframe(
        df_region.head(20),
        use_container_width=True,
        column_config={
            "TOTAL_EVS": st.column_config.NumberColumn("Total EVs", format="%d"),
            "BEV_PERCENTAGE": st.column_config.ProgressColumn("BEV %", min_value=0, max_value=100),
            "CAFV_ELIGIBLE_PCT": st.column_config.ProgressColumn("CAFV Eligible %", min_value=0, max_value=100),
        }
    )

with tab3:
    st.subheader("Manufacturer Market Share")
    top_makes = df_make.groupby("MAKE")["TOTAL_REGISTRATIONS"].sum().sort_values(ascending=False).head(10)
    st.bar_chart(top_makes)
    st.dataframe(df_make.head(15), use_container_width=True)

with tab4:
    st.subheader("Charging Infrastructure Coverage")
    if not df_coverage.empty:
        st.dataframe(
            df_coverage,
            use_container_width=True,
            column_config={
                "EVS_PER_STATION": st.column_config.NumberColumn("EVs/Station", format="%.0f"),
            }
        )
    else:
        st.info("No cities with charging station data available.")

st.divider()
st.caption("Data: Washington State DOL | Architecture: Bronze→Silver→Gold | Refresh: Dynamic Tables (1hr lag)")

def clear_cache():
    load_yoy_growth.clear()
    load_region_data.clear()
    load_make_model.clear()
    load_coverage.clear()

st.button("🔄 Refresh Data", on_click=clear_cache)
