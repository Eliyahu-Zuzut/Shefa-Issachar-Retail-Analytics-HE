-- ============================================================================
-- קובץ SQL: ניתוח נתונים מעמיק לאפליקציית "שפע בכפע" - רשת "שפע יששכר" (סניף יבנה)
-- מגיש הפרויקט: אליהו זוזות | Data Analyst
-- ============================================================================
-- השאילתות מסודרות על פי הסדר שבו נבנו החלקים של המטלה ומשולבות בדו"ח
-- בצורה דינמית להבאת תובנות ותמיכה בהמלצות על פי הנתונים.
--
-- מכיוון שהתאריכים נפרסו על פני טווח תאריכים יחסית גדול שכולל כמה עונות בשנה
-- ומגוון תאריכים ייחודיים ללוח השנה העברי שיכולים להשפיע באופן ישיר על התנהגות
-- הצרכנים והעובדים, בשלב ראשון יצרתי טבלת לוח שנה עברי ומזג אוויר המכילה את
-- התאריך העברי לצד פירוט מקיף על מה התרחש ומזג האוויר באותו יום.
-- המטרה של הטבלה היא לשמש כטבלת עזר להבנת דפוסים והתנהגויות של צרכנים ועובדים
-- והבדלי הכנסות. בחלק מהשאילתות תתבצע קריאה לנתונים מהטבלה:
-- FROM `bqproj26.my_tables.calendar_il_bigquery`
-- ============================================================================


-- ============================================================================
-- חלק 1: הצגת הנתונים (סטטיסטיקה תיאורית וקשרים בין משתנים)
-- ============================================================================

-- 1.1 שאילתא המציגה את התפלגות משך זמן הקנייה כהשפעה על 2 משתנים
-- (אחוז המכירות ותנועת הקונים).
-- נתונים נבחרים להצגה בגרף עמודות: זמן השהייה של לקוחות משלמים אל מול הנפח שלהם מאחוז המכירות.
SELECT
    CASE
        WHEN s.dwell_minutes < 15 THEN '00-14 דק׳'
        WHEN s.dwell_minutes < 30 THEN '15-29 דק׳'
        WHEN s.dwell_minutes < 45 THEN '30-44 דק׳'
        WHEN s.dwell_minutes < 60 THEN '45-59 דק׳'
        WHEN s.dwell_minutes < 75 THEN '60-74 דק׳'
        WHEN s.dwell_minutes < 90 THEN '75-89 דק׳'
        WHEN s.dwell_minutes < 105 THEN '90-104 דק׳'
        WHEN s.dwell_minutes < 120 THEN '105-119 דק׳'
        ELSE '120+ דק׳'
    END AS dwell_bracket,
    COUNT(*) AS transactions_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_sales
FROM `bqproj26.Final_Project_2026.log_sales` s
WHERE s.dwell_minutes IS NOT NULL
  AND s.customer_id IN (
      SELECT DISTINCT device_id
      FROM `bqproj26.Final_Project_2026.geolocation`
      WHERE role IN ('repeat_customer', 'one_time_customer')
  )
GROUP BY 1
ORDER BY MIN(s.dwell_minutes);


-- 1.2 שאילתא המציגה את השעות שבהן התבצעה פעילות (כמות העסקאות והאחוז שלהן בכל שעה).
-- הנתונים שנבחרו להצגה בגרף ציר זמן: השעות ביום אל מול כמות העסקאות בכל שעה ביום.
SELECT
    EXTRACT(HOUR FROM timestamp) AS hour_of_day,
    COUNT(*) AS transactions_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_day_sales
FROM `bqproj26.Final_Project_2026.log_sales`
GROUP BY 1
ORDER BY hour_of_day;


-- 1.3 שאילתא המציגה את התפלגות אמצעי התשלום.
-- גרף עמודות עם סך ההכנסות ואחוז ההכנסות מכל סוג אמצעי תשלום.
SELECT
    payment_method,
    COUNT(*) AS transactions_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_transactions,
    ROUND(SUM(total), 2) AS total_revenue_ils,
    ROUND(SUM(total) * 100.0 / SUM(SUM(total)) OVER(), 2) AS pct_revenue
FROM `bqproj26.Final_Project_2026.log_sales`
GROUP BY payment_method
ORDER BY total_revenue_ils DESC;


-- ----------------------------------------------------------------------------
-- גרפים להצגת 2 משתנים ומעלה
-- ----------------------------------------------------------------------------

-- 1.4 שאילתא שבודקת ממוצע סל קנייה וכמות ביקורים/עסקאות לכל סוג לקוח.
SELECT
    COALESCE(g.role, 'no_phone') AS customer_type,
    COUNT(DISTINCT s.sale_id) AS transactions_count,
    ROUND(AVG(s.total), 2) AS avg_basket_ils
FROM `bqproj26.Final_Project_2026.log_sales` s
LEFT JOIN (
    SELECT DISTINCT device_id, role
    FROM `bqproj26.Final_Project_2026.geolocation`
) g ON s.customer_id = g.device_id
GROUP BY customer_type
ORDER BY avg_basket_ils DESC;


-- 1.5 שאילתא המציגה את הקשר בין זמן השהייה לגובה סל הקנייה (בקפיצות של 10 דקות).
SELECT
    CAST(FLOOR(s.dwell_minutes / 10) * 10 AS INT64) AS dwell_bin_10min,
    CONCAT(
        CAST(FLOOR(s.dwell_minutes / 10) * 10 AS STRING),
        '-',
        CAST(FLOOR(s.dwell_minutes / 10) * 10 + 9 AS STRING),
        ' דק׳'
    ) AS dwell_range,
    ROUND(AVG(s.total), 2) AS avg_basket_ils
FROM `bqproj26.Final_Project_2026.log_sales` s
WHERE s.dwell_minutes IS NOT NULL
GROUP BY 1, 2
ORDER BY dwell_bin_10min;


-- 1.6 שאילתא המציגה את הקשר בין שעת הקנייה ואמצעי התשלום לגובה סל הקנייה.
-- תובנה חשובה המתגלה: הממוצע הגבוה של כרטיסי האשראי נובע משעות הערב (ימי חמישי) וכלל לא מימי שישי.
SELECT
    EXTRACT(HOUR FROM timestamp) AS sale_hour,
    payment_method,
    ROUND(AVG(total), 2) AS avg_basket_ils
FROM `bqproj26.Final_Project_2026.log_sales`
GROUP BY sale_hour, payment_method
ORDER BY sale_hour ASC, payment_method;


-- ============================================================================
-- חלק 2: מטריקות עסקיות, סגמנטציה, בקרת איכות ותפעול
-- ============================================================================

-- 2.1 מיפוי לקוחות:
-- שאילתא המציגה נתונים מלאים עבור כל מכשיר (כמות ביקורים, כמות רכישות, סך הוצאות,
-- ממוצע סל קנייה ומשך זמן שהייה ממוצע) וממפה את כל סוגי הלקוחות.
-- הערה חשובה: מכיוון שלקוחות ללא אפליקציה אינם מזוהים במכשיר במאגר, החישוב מציג כל רכישה
-- שלהם כרשומת לקוח נפרדת, דבר שלא בהכרח משקף לקוחות יחידים במציאות כי לקוח ללא אפליקציה
-- עשוי לבצע מספר רכישות.
WITH
    geo_users AS (
        SELECT
            device_id AS customer_identifier,
            role AS segment,
            COUNT(DISTINCT DATE(timestamp)) AS store_visit_days,
            COUNT(*) AS total_pings
        FROM `bqproj26.Final_Project_2026.geolocation`
        WHERE role IN ('repeat_customer', 'one_time_customer', 'not_paying')
        GROUP BY 1, 2
    ),
    sales_per_customer AS (
        -- נתוני רכישות ללקוחות עם אפליקציה
        SELECT
            customer_id,
            COUNT(*) AS total_purchases,
            ROUND(SUM(total), 2) AS total_spent_ils,
            ROUND(AVG(total), 2) AS avg_basket_ils,
            ROUND(AVG(dwell_minutes), 1) AS avg_dwell_minutes
        FROM `bqproj26.Final_Project_2026.log_sales`
        WHERE customer_id IS NOT NULL
        GROUP BY 1
    ),
    no_phone_users AS (
        -- לקוחות no_phone שקנו בקופה ללא אפליקציה (כל קנייה כרשומת לקוח נפרדת)
        SELECT
            CONCAT('no_phone_sale_', sale_id) AS customer_identifier,
            'no_phone' AS segment,
            1 AS store_visit_days,
            0 AS total_pings,
            1 AS total_purchases,
            ROUND(total, 2) AS total_spent_ils,
            ROUND(total, 2) AS avg_basket_ils,
            CAST(NULL AS FLOAT64) AS avg_dwell_minutes
        FROM `bqproj26.Final_Project_2026.log_sales`
        WHERE customer_id IS NULL
    )
-- איחוד של כל סוגי הלקוחות
SELECT
    g.customer_identifier,
    g.segment,
    g.store_visit_days,
    COALESCE(s.total_purchases, 0) AS total_purchases,
    COALESCE(s.total_spent_ils, 0.0) AS total_spent_ils,
    COALESCE(s.avg_basket_ils, 0.0) AS avg_basket_ils,
    s.avg_dwell_minutes
FROM geo_users g
LEFT JOIN sales_per_customer s
    ON g.customer_identifier = s.customer_id
UNION ALL
SELECT
    customer_identifier,
    segment,
    store_visit_days,
    total_purchases,
    total_spent_ils,
    avg_basket_ils,
    avg_dwell_minutes
FROM no_phone_users
ORDER BY total_spent_ils DESC, total_purchases DESC;


-- 2.2 שאילתא המציגה סיכום נתונים סטטיסטי של כל סוג לקוח (טבלת הסיכום בדו"ח).
WITH
    app_customers AS (
        SELECT
            g.role AS customer_segment,
            COUNT(DISTINCT g.device_id) AS distinct_devices,
            COUNT(s.sale_id) AS total_transactions,
            CAST(ROUND(SUM(total), 0) AS NUMERIC) AS total_revenue_ils,
            ROUND(COALESCE(AVG(s.total), 0), 2) AS avg_basket_ils,
            ROUND(AVG(s.dwell_minutes), 1) AS avg_dwell_minutes,
            ROUND(AVG(g.active_days), 1) AS avg_visit_days,
            ROUND(COUNT(s.sale_id) / COUNT(DISTINCT g.device_id), 1) AS avg_purchases_per_customer
        FROM (
            SELECT device_id, role, COUNT(DISTINCT DATE(timestamp)) AS active_days
            FROM `bqproj26.Final_Project_2026.geolocation`
            WHERE role IN ('repeat_customer', 'one_time_customer', 'not_paying')
            GROUP BY 1, 2
        ) g
        LEFT JOIN `bqproj26.Final_Project_2026.log_sales` s
            ON g.device_id = s.customer_id
        GROUP BY 1
    ),
    no_phone_customers AS (
        SELECT
            'no_phone' AS customer_segment,
            CAST(NULL AS INT64) AS distinct_devices,
            COUNT(*) AS total_transactions,
            CAST(ROUND(SUM(total), 0) AS NUMERIC) AS total_revenue_ils,
            ROUND(AVG(total), 2) AS avg_basket_ils,
            CAST(NULL AS FLOAT64) AS avg_dwell_minutes,
            CAST(NULL AS FLOAT64) AS avg_visit_days,
            CAST(NULL AS FLOAT64) AS avg_purchases_per_customer
        FROM `bqproj26.Final_Project_2026.log_sales`
        WHERE customer_id IS NULL
    )
SELECT * FROM app_customers
UNION ALL
SELECT * FROM no_phone_customers
ORDER BY total_revenue_ils DESC;


-- 2.3 מיפוי עובדים:
-- שאילתא המציגה סיכום נתונים עבור כל מכשיר של כל עובד.
SELECT
    CASE g.role
        WHEN 'manager' THEN 'Managers'
        WHEN 'senior_general_worker' THEN 'Senior Staff'
        WHEN 'cashier' THEN 'Cashiers'
        WHEN 'butcher' THEN 'Butchers'
        WHEN 'general_worker' THEN 'General Staff'
        WHEN 'security_guy' THEN 'Security'
        WHEN 'delivery_guy' THEN 'Supply Workers'
    END AS role_category,
    g.device_id,
    COUNT(DISTINCT DATE(g.timestamp)) AS active_work_days,
    COUNT(*) AS total_shift_pings,
    ANY_VALUE(g.area) AS primary_work_area,
    MIN(TIME(g.timestamp)) AS typical_shift_start,
    MAX(TIME(g.timestamp)) AS typical_shift_end,
    ROUND(AVG(g.accuracy_m), 1) AS avg_accuracy_meters
FROM `bqproj26.Final_Project_2026.geolocation` g
WHERE g.role NOT IN ('repeat_customer', 'one_time_customer', 'not_paying')
GROUP BY g.role, g.device_id
ORDER BY
    CASE g.role
        WHEN 'manager' THEN 1
        WHEN 'senior_general_worker' THEN 2
        WHEN 'cashier' THEN 3
        WHEN 'butcher' THEN 4
        WHEN 'general_worker' THEN 5
        WHEN 'security_guy' THEN 6
        WHEN 'delivery_guy' THEN 7
    END,
    g.device_id;


-- 2.4 קוד בונוס לזיהוי הקטגוריה של כל מכשיר (עובדים ולקוחות) ללא שימוש בעמודת role.
WITH
    device_behavioral_features AS (
        SELECT
            device_id,
            COUNT(*) AS total_pings,
            COUNT(DISTINCT DATE(timestamp)) AS active_days,
            ROUND(COUNT(*) / COUNT(DISTINCT DATE(timestamp)), 1) AS avg_pings_per_day,
            MIN(TIME(timestamp)) AS earliest_time,
            MAX(TIME(timestamp)) AS latest_time,
            -- חישוב אחוז הזמן שהמכשיר שהה בכל אזור בסופר
            ROUND(COUNTIF(area = 'HEAD_OFFICE') * 100.0 / COUNT(*), 1) AS pct_in_office,
            ROUND(COUNTIF(area = 'BUTCHERY') * 100.0 / COUNT(*), 1) AS pct_in_butchery,
            ROUND(COUNTIF(area = 'WAREHOUSE') * 100.0 / COUNT(*), 1) AS pct_in_warehouse,
            ROUND(COUNTIF(area = 'CASH_REGISTERS') * 100.0 / COUNT(*), 1) AS pct_in_cash_registers,
            ROUND(COUNTIF(area = 'SUPERMARKET') * 100.0 / COUNT(*), 1) AS pct_in_supermarket,
            ROUND(COUNTIF(area = 'PARKING') * 100.0 / COUNT(*), 1) AS pct_in_parking
        FROM `bqproj26.Final_Project_2026.geolocation`
        GROUP BY 1
    ),
    sales_behavior AS (
        SELECT
            customer_id,
            COUNT(*) AS total_sales
        FROM `bqproj26.Final_Project_2026.log_sales`
        WHERE customer_id IS NOT NULL
        GROUP BY 1
    )
SELECT
    d.device_id,
    d.active_days,
    d.avg_pings_per_day,
    COALESCE(s.total_sales, 0) AS total_purchases_count,
    CASE
        WHEN d.pct_in_office >= 50 THEN 'manager'
        WHEN d.pct_in_butchery >= 50 THEN 'butcher'
        WHEN d.pct_in_warehouse >= 50 THEN 'delivery_guy'
        WHEN d.pct_in_cash_registers >= 80 AND d.avg_pings_per_day >= 100 THEN 'cashier'
        WHEN d.pct_in_parking >= 80 AND d.avg_pings_per_day >= 100 THEN 'security_guy'
        WHEN d.pct_in_supermarket >= 80
             AND d.avg_pings_per_day >= 100
             AND d.active_days >= 100 THEN 'senior_general_worker'
        WHEN d.pct_in_supermarket >= 80 AND d.avg_pings_per_day >= 100 THEN 'general_worker'
        WHEN COALESCE(s.total_sales, 0) = 0 THEN 'not_paying'
        WHEN s.total_sales >= 10 THEN 'repeat_customer'
        ELSE 'one_time_customer'
    END AS predicted_role
FROM device_behavioral_features d
LEFT JOIN sales_behavior s
    ON d.device_id = s.customer_id
ORDER BY predicted_role, d.device_id;


-- 2.5 חישוב כמות שידורים חריגים (accuracy_m > 30) והאחוז שלהם מכלל הדאטה.
SELECT
    COUNT(*) AS total_pings_count,
    COUNTIF(accuracy_m > 30) AS outliers_count_above_30m,
    COUNTIF(accuracy_m <= 30) AS normal_pings_count,
    ROUND(COUNTIF(accuracy_m > 30) * 100.0 / COUNT(*), 2) AS pct_outliers_above_30m,
    ROUND(MIN(accuracy_m), 1) AS min_accuracy_meters,
    ROUND(MAX(accuracy_m), 1) AS max_accuracy_meters,
    ROUND(AVG(accuracy_m), 1) AS avg_accuracy_meters
FROM `bqproj26.Final_Project_2026.geolocation`;


-- 2.6 איתור תפקיד / מזהה מכשיר עם חריגה קבועה:
-- המאבטח הוא בעל החריגה הגבוהה ביותר ככל הנראה בגלל שהוא נמצא על התפר שבין שני אזורים
-- (החנייה לכל גודלה והכניסה לסופר / מיסוך בטון) ובנוסף מכשיר הבדיקה שלו גורם לשיבוש בשידורים.
-- מחשבה נוספת: מה שגורם לחריגה הוא תזוזה מהירה בין אזורים - ככל שיש יותר תזוזה יש יותר חריגה,
-- לדוגמה המנהלת שירה והקצבים שמסתובבים באזורים שונים מדי פעם.
SELECT
    role,
    COUNT(*) AS total_pings,
    COUNTIF(accuracy_m > 30) AS high_acc_outliers_count,
    ROUND(COUNTIF(accuracy_m > 30) * 100.0 / COUNT(*), 2) AS pct_outliers,
    ROUND(AVG(accuracy_m), 1) AS avg_accuracy_m,
    ROUND(MAX(accuracy_m), 1) AS max_accuracy_m,
    ROUND(MIN(accuracy_m), 1) AS min_accuracy_m
FROM `bqproj26.Final_Project_2026.geolocation`
GROUP BY role
ORDER BY pct_outliers DESC;


-- 2.7 יצירת דגל לשידורים חריגים על מנת לסווג ולמתן אותם במקום למחוק אותם:
-- שאילתת בדיקה לזיהוי סוגי שידורים חריגים על ידי סיווג וחלוקה לקטגוריות,
-- לזיהוי השידורים החריגים המשפיעים על הממוצע בניתוח התנהגותי, גיאוגרפי או תפעולי.
SELECT
    device_id,
    timestamp,
    lat,
    lon,
    area,
    role,
    accuracy_m AS raw_accuracy_m,
    -- יצירת דגל לערכים חריגים
    CASE
        WHEN accuracy_m <= 30 THEN TRUE
        ELSE FALSE
    END AS is_gps_reliable,
    LEAST(accuracy_m, 50.0) AS capped_accuracy_m,
    CASE
        WHEN accuracy_m <= 30 THEN 'מדויק להגדרה (עד 30 מטר)'
        WHEN accuracy_m <= 50 THEN 'סטייה מתונה (31-50 מטר)'
        ELSE 'סטייה קיצונית (מאבטח / חריג)'
    END AS accuracy_tier
FROM `bqproj26.Final_Project_2026.geolocation`;


-- 2.8 שאילתא הבודקת את ביצועי קליטת האפליקציה לכל סוג תפקיד ולכולם ביחד (מול רף ה-40%).
WITH
    customer_visits AS (
        -- שלב 1: חישוב משך השהייה וכמות השידורים בפועל לכל ביקור
        SELECT
            device_id,
            role,
            DATE(timestamp) AS visit_date,
            MIN(timestamp) AS visit_start,
            MAX(timestamp) AS visit_end,
            TIMESTAMP_DIFF(MAX(timestamp), MIN(timestamp), MINUTE) + 1 AS duration_minutes,
            COUNT(*) AS pings_count
        FROM `bqproj26.Final_Project_2026.geolocation`
        GROUP BY 1, 2, 3
        -- סינון ביקורים קצרים מ-5 דקות כדי למנוע עיוותי חלוקה
        HAVING duration_minutes >= 5
    )
-- שלב 2: פילוח לפי סוג לקוח/תפקיד ובדיקה כללית מול רף ה-40%
SELECT
    role AS customer_segment,
    -- קצב הקליטה הממוצע בפועל
    ROUND(AVG(pings_count * 100.0 / duration_minutes), 2) AS avg_reception_rate_pct
FROM customer_visits
GROUP BY role
UNION ALL
SELECT
    'כלל הלקוחות (ממוצע משוקלל)' AS customer_segment,
    ROUND(AVG(pings_count * 100.0 / duration_minutes), 2) AS avg_reception_rate_pct
FROM customer_visits;


-- 2.9 בונוס: שאילתא הבודקת ערכים חריגים נוספים העלולים להשפיע על ניתוח הדאטה
-- (סכומי קנייה גבוהים במיוחד וזמני שהייה גבוהים או נמוכים מאוד).
WITH
    sales_statistics AS (
        -- חישוב ממוצע וסטיות תקן לסכומים ולמשך שהייה
        SELECT
            ROUND(AVG(total), 2) AS mean_total,
            ROUND(STDDEV(total), 2) AS std_total,
            ROUND(AVG(dwell_minutes), 2) AS mean_dwell,
            ROUND(STDDEV(dwell_minutes), 2) AS std_dwell
        FROM `bqproj26.Final_Project_2026.log_sales`
        WHERE dwell_minutes IS NOT NULL
    )
SELECT
    -- 1. חריגי סכום מעל 3 סטיות תקן (מעל ~1,240 ש"ח)
    COUNTIF(s.total > (stat.mean_total + 3 * stat.std_total)) AS extreme_high_spend_outliers,
    ROUND(
        MIN(CASE WHEN s.total > (stat.mean_total + 3 * stat.std_total) THEN s.total END),
        2
    ) AS min_high_spend_outlier,
    ROUND(MAX(s.total), 2) AS max_spend_in_data,
    -- 2. שהייה מינימלית חריגה של דקה אחת
    COUNTIF(s.dwell_minutes = 1.0) AS min_dwell_1min_count,
    -- 3. שהייה ממושכת חריגה (מעל שעתיים - 120 דקות)
    COUNTIF(s.dwell_minutes >= 120.0) AS long_dwell_over_2hours_count,
    ROUND(MAX(s.dwell_minutes), 1) AS max_dwell_in_data
FROM `bqproj26.Final_Project_2026.log_sales` s
CROSS JOIN sales_statistics stat
WHERE s.dwell_minutes IS NOT NULL;


-- 2.10 אספקת סחורה לסופר: איתור ומיפוי מכשירי ספקים.
SELECT
    device_id,
    COUNT(*) AS total_pings,
    COUNT(DISTINCT DATE(timestamp)) AS active_days,
    MIN(TIME(timestamp)) AS first_ping_time,
    MAX(TIME(timestamp)) AS last_ping_time,
    ROUND(AVG(accuracy_m), 2) AS avg_accuracy_m,
    -- בדיקת התפלגות אזורים לכל מכשיר
    COUNT(DISTINCT area) AS unique_areas,
    STRING_AGG(DISTINCT area, ', ') AS areas_visited
FROM `bqproj26.Final_Project_2026.geolocation`
WHERE role = 'delivery_guy'
GROUP BY device_id
ORDER BY device_id;


-- 2.11 קוד בונוס: זיהוי מכשירי ספקים על פי מיקומים ושעות ללא שימוש בעמודת role.
WITH device_features AS (
    SELECT
        device_id,
        COUNT(*) AS total_pings,
        -- שיעור הפינגים במחסן
        COUNTIF(area = 'WAREHOUSE') / COUNT(*) AS warehouse_ratio,
        -- שיעור הפינגים לפני 07:00 בבוקר
        COUNTIF(EXTRACT(HOUR FROM timestamp) < 7) / COUNT(*) AS early_morning_ratio,
        -- שיעור הפינגים בימי שני (2) וחמישי (5)
        COUNTIF(EXTRACT(DAYOFWEEK FROM timestamp) IN (2, 5)) / COUNT(*) AS mon_thu_ratio,
        MIN(TIME(timestamp)) AS min_time,
        MAX(TIME(timestamp)) AS max_time,
        COUNT(DISTINCT DATE(timestamp)) AS active_days
    FROM `bqproj26.Final_Project_2026.geolocation`
    GROUP BY device_id
)
SELECT
    device_id,
    CASE
        WHEN warehouse_ratio >= 0.90
         AND early_morning_ratio >= 0.90
         AND mon_thu_ratio = 1.0
        THEN 'delivery_guy'
        ELSE 'other'
    END AS predicted_role,
    total_pings,
    ROUND(warehouse_ratio * 100, 1) AS pct_warehouse,
    ROUND(early_morning_ratio * 100, 1) AS pct_early_morning,
    active_days,
    min_time,
    max_time
FROM device_features
WHERE warehouse_ratio >= 0.90 AND early_morning_ratio >= 0.90
ORDER BY device_id;


-- 2.12 שאילתא המוציאה את נתוני ימי אספקת הסחורה: מה התרחש בהם והאם בוצעה אספקה.
-- ימים בהם תוכננה אספקה אך לא הגיע שום ספק בפועל: 2 ימים היו חגים רשמיים שבהם הסניף סגור
-- (חג שבועות ויום הכיפורים), אך ב-3 ימים פתוחים אין הצדקה להיעדרות - וכולם בימי חמישי
-- (פגיעה ישירה במלאי לקראת סוף השבוע). בכל אותם ימים קיימת סיבה צדדית בלוח השנה שיכולה להתריע מראש
-- (כמו החופש הגדול, ערב בלאק פריידי וראש חודש) - המלצה שהמנהלת תוודא מול הספקים מראש.
WITH planned_deliveries AS (
    SELECT
        date_key,
        day_of_week_num,
        day_name_he,
        event_name,
        expected_store_status,
        is_rest_day_il
    FROM `bqproj26.my_tables.calendar_il_bigquery`
    WHERE date_key BETWEEN '2025-06-01' AND '2025-11-30'
      AND day_of_week_num IN (2, 5) -- ימי שני (2) וחמישי (5)
),
actual_deliveries AS (
    SELECT
        DATE(timestamp) AS delivery_date,
        COUNT(DISTINCT device_id) AS delivery_devices,
        COUNT(*) AS delivery_pings
    FROM `bqproj26.Final_Project_2026.geolocation`
    WHERE role = 'delivery_guy'
    GROUP BY delivery_date
)
SELECT
    p.date_key AS scheduled_date,
    p.day_name_he AS day_of_week,
    p.expected_store_status,
    p.event_name,
    p.is_rest_day_il,
    COALESCE(a.delivery_pings, 0) AS actual_pings,
    COALESCE(a.delivery_devices, 0) AS actual_suppliers,
    CASE
        WHEN p.expected_store_status = 'Closed' THEN 'סניף סגור (חג רשמי - היעדרות תקינה)'
        ELSE 'כשל באספקה (סניף פתוח ללא הגעת ספקים)'
    END AS operational_diagnosis
FROM planned_deliveries p
LEFT JOIN actual_deliveries a ON p.date_key = a.delivery_date
WHERE a.delivery_date IS NULL
ORDER BY p.date_key;


-- 2.13 זיהוי הלקוחות המתמידים של הסופר:
-- א. טופ 6 לקוחות שמגיעים לסניף בתדירות הגבוהה ביותר (מקום 5 ו-6 בתיקו של 97 ביקורים,
-- ולכן צורף סך ההוצאה הכספית להכרעה על המקום ה-5).
SELECT
    customer_id,
    COUNT(sale_id) AS total_count_sale,
    ROUND(SUM(total), 2) AS total_spent
FROM `bqproj26.Final_Project_2026.log_sales`
GROUP BY customer_id
HAVING customer_id IS NOT NULL
ORDER BY total_count_sale DESC
LIMIT 6;

-- ב. טופ 5 הלקוחות שהוציאו הכי הרבה כסף בסופר (מצטבר).
SELECT
    customer_id,
    ROUND(SUM(total), 2) AS total_purchase
FROM `bqproj26.Final_Project_2026.log_sales`
GROUP BY customer_id
HAVING customer_id IS NOT NULL
ORDER BY total_purchase DESC
LIMIT 5;


-- 2.14 ניתוח שעות הפעילות האמיתיות של הסופר (מפת חום תלת-משתנית):
-- השעות שבהן יש נתוני מיקום של לקוחות (שעות וימים ללא לקוחות/פעילות מסומנים בספרה 0).
WITH hours_grid AS (
    SELECT hour_of_day, FORMAT('%02d:00', hour_of_day) AS hour_label
    FROM UNNEST(GENERATE_ARRAY(7, 22)) AS hour_of_day
),
daily_hourly_customers AS (
    SELECT
        EXTRACT(DAYOFWEEK FROM timestamp) AS day_num,
        EXTRACT(HOUR FROM timestamp) AS hour_of_day,
        DATE(timestamp) AS visit_date,
        COUNT(DISTINCT device_id) AS unique_devices_in_hour
    FROM `bqproj26.Final_Project_2026.geolocation`
    WHERE role IN ('repeat_customer', 'one_time_customer')
    GROUP BY day_num, hour_of_day, visit_date
),
avg_by_day_hour AS (
    SELECT
        day_num,
        hour_of_day,
        ROUND(AVG(unique_devices_in_hour), 1) AS avg_customers
    FROM daily_hourly_customers
    GROUP BY day_num, hour_of_day
)
SELECT
    h.hour_label AS `שעה`,
    COALESCE(MAX(CASE WHEN a.day_num = 1 THEN a.avg_customers END), 0) AS `ראשון`,
    COALESCE(MAX(CASE WHEN a.day_num = 2 THEN a.avg_customers END), 0) AS `שני`,
    COALESCE(MAX(CASE WHEN a.day_num = 3 THEN a.avg_customers END), 0) AS `שלישי`,
    COALESCE(MAX(CASE WHEN a.day_num = 4 THEN a.avg_customers END), 0) AS `רביעי`,
    COALESCE(MAX(CASE WHEN a.day_num = 5 THEN a.avg_customers END), 0) AS `חמישי`,
    COALESCE(MAX(CASE WHEN a.day_num = 6 THEN a.avg_customers END), 0) AS `שישי`
FROM hours_grid h
LEFT JOIN avg_by_day_hour a ON h.hour_of_day = a.hour_of_day
GROUP BY h.hour_of_day, h.hour_label
ORDER BY h.hour_of_day;


-- ============================================================================
-- חלק 3: המלצות עסקיות להנהלת הרשת והסניף (סעיף 3 ב')
-- ============================================================================

-- 3.1 אסטרטגיית התרחבות: שאילתא המנתחת בפירוט היכן כדאי לפתוח סניף חדש.
WITH raw_chains AS (
    -- זיהוי וסיווג שמות הרשתות בכל עיר
    SELECT
        TRIM(s.city) AS city,
        CASE
            WHEN REGEXP_CONTAINS(s.name, r'(?i)שופרסל|יש חסד|יש בשכונה|Shufersal') THEN 'שופרסל / יש'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)רמי לוי') THEN 'רמי לוי'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)אושר עד') THEN 'אושר עד'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)יינות ביתן|מגה') THEN 'יינות ביתן / מגה'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)יוחננוף') THEN 'יוחננוף'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)מחסני השוק') THEN 'מחסני השוק'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)ויקטורי') THEN 'ויקטורי'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)AM:PM') THEN 'AM:PM'
            WHEN s.name IS NULL OR TRIM(s.name) = '' THEN 'ללא שם (מכולת/פרטי)'
            ELSE 'סופר פרטי / אחר'
        END AS chain_name
    FROM `bqproj26.Final_Project_2026.supermarkets_il` s
),
chain_counts AS (
    SELECT
        city,
        chain_name,
        COUNT(*) AS branches_count
    FROM raw_chains
    GROUP BY city, chain_name
),
ranked_chains AS (
    SELECT
        city,
        chain_name,
        branches_count,
        -- דירוג למציאת הרשת הארצית הדומיננטית ביותר בעיר
        ROW_NUMBER() OVER(
            PARTITION BY city
            ORDER BY
                CASE WHEN chain_name NOT IN ('ללא שם (מכולת/פרטי)', 'סופר פרטי / אחר') THEN 1 ELSE 2 END,
                branches_count DESC
        ) AS rank_in_city,
        CONCAT(chain_name, ' (', CAST(branches_count AS STRING), ')') AS chain_summary_item
    FROM chain_counts
),
city_competition AS (
    SELECT
        city,
        MAX(CASE WHEN rank_in_city = 1 THEN chain_name END) AS dominant_chain,
        MAX(CASE WHEN rank_in_city = 1 THEN branches_count END) AS dominant_chain_branches,
        STRING_AGG(chain_summary_item, ', ' ORDER BY branches_count DESC) AS all_chains_in_city
    FROM ranked_chains
    GROUP BY city
)
SELECT
    l.city_name,
    l.total_population,
    COUNT(s.id) AS supermarkets_count,
    -- כמות תושבים על כל סופר (אם יש 0 סופרים - כל האוכלוסייה ללא מענה)
    COALESCE(ROUND(l.total_population / NULLIF(COUNT(s.id), 0), 0), l.total_population) AS people_per_supermarket,
    -- מדד סופרים ל-10,000 נפש
    ROUND(COUNT(s.id) * 10000.0 / l.total_population, 2) AS supermarkets_per_10k,
    -- תמונת התחרות בעיר
    COALESCE(c.dominant_chain, 'אין סופרים בעיר') AS dominant_chain,
    COALESCE(c.dominant_chain_branches, 0) AS dominant_chain_branches,
    COALESCE(c.all_chains_in_city, 'אין מתחרים ממופים') AS competitors_breakdown,
    CASE
        WHEN COUNT(s.id) = 0
            THEN '1. הזדמנות ואקום: 0 סופרים בעיר (אפס תחרות רשתות)'
        WHEN ROUND(COUNT(s.id) * 10000.0 / l.total_population, 2) < 1.0
         AND COALESCE(c.dominant_chain_branches, 0) <= 1
            THEN '2. אור ירוק לפתיחה: מחסור חמור בסופרים + אין רשת חוסמת!'
        WHEN ROUND(COUNT(s.id) * 10000.0 / l.total_population, 2) < 1.0
         AND c.dominant_chain NOT IN ('ללא שם (מכולת/פרטי)', 'סופר פרטי / אחר')
         AND c.dominant_chain_branches >= 3
            THEN '3. מלכודת תחרות (לא לפתוח): מעט סופרים אך רשת חזקה שולטת בעיר'
        WHEN ROUND(COUNT(s.id) * 10000.0 / l.total_population, 2) >= 3.5
            THEN '5. שוק רווי וצפוף (לא לפתוח): עודף סופרים ביחס לתושבים'
        ELSE '4. שוק מאוזן / תחרות בינונית'
    END AS executive_recommendation
FROM `bqproj26.Final_Project_2026.Lamas_Israel_2026` l
LEFT JOIN `bqproj26.Final_Project_2026.supermarkets_il` s
    ON TRIM(l.city_name) = TRIM(s.city)
LEFT JOIN city_competition c
    ON TRIM(l.city_name) = c.city
WHERE l.total_population >= 10000
GROUP BY
    l.city_name,
    l.total_population,
    c.dominant_chain,
    c.dominant_chain_branches,
    c.all_chains_in_city
ORDER BY
    supermarkets_per_10k ASC,
    l.total_population DESC;


-- 3.2 שאילתא המציגה את הערים שבהן השוק רווי מאוד וממש לא כדאי לפתוח סניף נוסף.
SELECT
    l.city_name,
    l.total_population,
    COUNT(s.id) AS supermarkets_count,
    ROUND(l.total_population / COUNT(s.id), 0) AS people_per_supermarket,
    ROUND(COUNT(s.id) * 10000.0 / l.total_population, 2) AS supermarkets_per_10k,
    'שוק רווי מאוד - לא לפתוח!' AS recommendation
FROM `bqproj26.Final_Project_2026.Lamas_Israel_2026` l
JOIN `bqproj26.Final_Project_2026.supermarkets_il` s
    ON TRIM(l.city_name) = TRIM(s.city)
WHERE l.total_population >= 20000
GROUP BY l.city_name, l.total_population
ORDER BY supermarkets_per_10k DESC;


-- 3.3 שאילתא הבוחנת את ביצועי ימות השבוע לאיתור הימים המתאימים ביותר למבצעים והנחות.
WITH open_days AS (
    SELECT date_key, day_of_week_num, day_name_he
    FROM `bqproj26.my_tables.calendar_il_bigquery`
    WHERE date_key BETWEEN '2025-06-01' AND '2025-11-30'
      AND expected_store_status != 'Closed'
),
daily_sales AS (
    SELECT
        DATE(timestamp) AS sale_date,
        COUNT(*) AS tx_count,
        SUM(total) AS daily_revenue,
        AVG(total) AS avg_basket
    FROM `bqproj26.Final_Project_2026.log_sales`
    GROUP BY sale_date
),
daily_customers AS (
    SELECT
        DATE(timestamp) AS visit_date,
        COUNT(DISTINCT CASE
            WHEN role IN ('repeat_customer', 'one_time_customer', 'not_paying') THEN device_id
        END) AS unique_app_customers
    FROM `bqproj26.Final_Project_2026.geolocation`
    GROUP BY visit_date
)
SELECT
    o.day_of_week_num,
    o.day_name_he,
    COUNT(o.date_key) AS total_open_days,
    ROUND(AVG(c.unique_app_customers), 1) AS avg_daily_app_customers,
    ROUND(AVG(s.tx_count), 1) AS avg_daily_transactions,
    ROUND(AVG(s.daily_revenue), 0) AS avg_daily_revenue_ils,
    ROUND(AVG(s.avg_basket), 1) AS avg_basket_ils
FROM open_days o
LEFT JOIN daily_sales s ON o.date_key = s.sale_date
LEFT JOIN daily_customers c ON o.date_key = c.visit_date
GROUP BY o.day_of_week_num, o.day_name_he
ORDER BY o.day_of_week_num;


-- 3.4 סעיף עבור מחלקת משאבי אנוש (HR) - חישוב קיבולת קופאי לשעה:
-- שאילתא המציגה כמה זמן לוקח לערוך חשבון לכל סוג לקוח על פי ממוצע סלי הקנייה,
-- וכמה לקוחות קופאי משרת בשעה כולל מרווח ביטחון של 20%.
WITH customer_checkout AS (
    SELECT
        s.sale_id,
        s.customer_id,
        s.total,
        COUNT(g.timestamp) AS reg_pings,
        COALESCE(TIMESTAMP_DIFF(s.timestamp, MIN(g.timestamp), SECOND) / 60.0, 0) AS mins_to_pay
    FROM `bqproj26.Final_Project_2026.log_sales` s
    LEFT JOIN `bqproj26.Final_Project_2026.geolocation` g
        ON s.customer_id = g.device_id
       AND DATE(s.timestamp) = DATE(g.timestamp)
       AND g.area = 'CASH_REGISTERS'
    GROUP BY s.sale_id, s.customer_id, s.total, s.timestamp
),
base_metrics AS (
    SELECT
        AVG(CASE WHEN customer_id IS NOT NULL THEN (reg_pings / 0.40) + mins_to_pay END) AS net_mins_app,
        AVG(CASE WHEN customer_id IS NOT NULL THEN total END) AS avg_basket_app,
        AVG(CASE WHEN customer_id IS NULL THEN total END) AS avg_basket_no_phone
    FROM customer_checkout
)
SELECT
    ROUND(avg_basket_app, 2) AS avg_basket_app_ils,
    ROUND(avg_basket_no_phone, 2) AS avg_basket_no_phone_ils,
    ROUND(net_mins_app, 2) AS net_service_mins_app,
    ROUND(net_mins_app * (avg_basket_no_phone / avg_basket_app), 2) AS net_service_mins_no_phone,
    ROUND(net_mins_app * 1.20, 2) AS gross_mins_app_with_safety,
    ROUND(net_mins_app * (avg_basket_no_phone / avg_basket_app) * 1.20, 2) AS gross_mins_no_phone_with_safety,
    ROUND(60.0 / (net_mins_app * 1.20), 1) AS max_app_customers_per_cashier_hour,
    ROUND(60.0 / (net_mins_app * (avg_basket_no_phone / avg_basket_app) * 1.20), 1) AS max_no_phone_customers_per_cashier_hour
FROM base_metrics;


-- 3.5 מודל שיבוץ קופאים בפועל מול כמות נדרשת בכל שעה לאורך קבוצות ימות השבוע.
-- הערה חשובה: החישוב בוחן את שעות הפעילות הרשמיות של הסופר; מומלץ תמיד להצליב מול לוח השנה לימי חג ואירועים.
WITH store_hourly_staff AS (
    -- כמות הקופאים בפועל בכל שעה מתוך חתימות הזמן האמיתיות בשעות פתיחת הסופר
    SELECT
        DATE(timestamp) AS work_date,
        EXTRACT(DAYOFWEEK FROM timestamp) AS day_of_week_num,
        EXTRACT(HOUR FROM timestamp) AS hr,
        COUNT(DISTINCT CASE WHEN role = 'cashier' THEN device_id END) AS active_cashiers
    FROM `bqproj26.Final_Project_2026.geolocation`
    WHERE (EXTRACT(DAYOFWEEK FROM timestamp) IN (1, 2, 3) AND TIME(timestamp) BETWEEN '07:30:00' AND '21:00:00')
       OR (EXTRACT(DAYOFWEEK FROM timestamp) IN (4, 5)    AND TIME(timestamp) BETWEEN '07:30:00' AND '22:00:00')
       OR (EXTRACT(DAYOFWEEK FROM timestamp) = 6          AND TIME(timestamp) BETWEEN '07:00:00' AND '15:00:00')
    GROUP BY 1, 2, 3
),
hourly_sales AS (
    -- כמות הלקוחות שעברו בקופה בכל שעה מתוך טבלת המכירות
    SELECT
        DATE(timestamp) AS work_date,
        EXTRACT(HOUR FROM timestamp) AS hr,
        COUNTIF(customer_id IS NOT NULL) AS app_customers,
        COUNTIF(customer_id IS NULL) AS no_phone_customers,
        COUNT(sale_id) AS total_customers
    FROM `bqproj26.Final_Project_2026.log_sales`
    GROUP BY 1, 2
)
SELECT
    CASE
        WHEN g.day_of_week_num IN (1, 2, 3) THEN '1. ימי א-ג (07:30-21:00)'
        WHEN g.day_of_week_num IN (4, 5)    THEN '2. ימי ד-ה (07:30-22:00)'
        WHEN g.day_of_week_num = 6          THEN '3. יום ו - ערב שבת (07:00-15:00)'
    END AS day_group,
    g.hr AS hour_num,
    FORMAT('%02d:00', g.hr) AS hour_slot,
    -- ממוצע לקוחות בשעה
    ROUND(AVG(COALESCE(s.app_customers, 0)), 1) AS avg_app_customers,
    ROUND(AVG(COALESCE(s.no_phone_customers, 0)), 1) AS avg_no_phone_customers,
    ROUND(AVG(COALESCE(s.total_customers, 0)), 1) AS avg_total_customers,
    -- הערכת זמן עבודה נדרש בדקות (לפי תוצאות שאילתת הקיבולת: 3.66 דק' לאפליקציה ו-2.04 דק' ללא טלפון)
    ROUND(AVG(COALESCE(s.app_customers, 0)) * 3.66 + AVG(COALESCE(s.no_phone_customers, 0)) * 2.04, 1) AS required_work_minutes,
    -- כמה קופאים באמת צריך לעומת כמה קופאים יש בפועל
    CAST(CEIL((AVG(COALESCE(s.app_customers, 0)) * 3.66 + AVG(COALESCE(s.no_phone_customers, 0)) * 2.04) / 60.0) AS INT64) AS required_cashiers,
    ROUND(AVG(g.active_cashiers), 1) AS actual_cashiers,
    -- פער הקופאים (במינוס = מחסור / צוואר בקבוק, בפלוס = עודף)
    CAST(
        ROUND(AVG(g.active_cashiers), 0) -
        CEIL((AVG(COALESCE(s.app_customers, 0)) * 3.66 + AVG(COALESCE(s.no_phone_customers, 0)) * 2.04) / 60.0)
        AS INT64
    ) AS cashier_gap,
    CASE
        WHEN ROUND(AVG(g.active_cashiers), 0) -
             CEIL((AVG(COALESCE(s.app_customers, 0)) * 3.66 + AVG(COALESCE(s.no_phone_customers, 0)) * 2.04) / 60.0) < 0
            THEN 'מחסור בקופאים (צוואר בקבוק)'
        WHEN ROUND(AVG(g.active_cashiers), 0) -
             CEIL((AVG(COALESCE(s.app_customers, 0)) * 3.66 + AVG(COALESCE(s.no_phone_customers, 0)) * 2.04) / 60.0) >= 2
            THEN 'עודף כוח אדם (אבטלה סמויה)'
        ELSE 'שיבוץ מאוזן ותקין'
    END AS staffing_status
FROM store_hourly_staff g
LEFT JOIN hourly_sales s
    ON g.work_date = s.work_date AND g.hr = s.hr
GROUP BY 1, 2, 3
ORDER BY 1, 2;


-- 3.6 שאילתא המציגה הכנסות לכל תאריך לצד נתוני מזג אוויר ותיאור האירוע באותו יום.
SELECT
    DATE(s.timestamp) AS sale_date,
    ROUND(SUM(s.total), 2) AS daily_total_sales,
    c.event_name,
    c.weather_status_he,
    c.day_name_he,
    c.day_of_week_num
FROM `bqproj26.Final_Project_2026.log_sales` s
LEFT JOIN `bqproj26.my_tables.calendar_il_bigquery` c
    ON DATE(s.timestamp) = c.date_key
GROUP BY
    sale_date,
    c.event_name,
    c.weather_status_he,
    c.day_name_he,
    c.day_of_week_num
ORDER BY sale_date ASC;


-- 3.7 סעיף עבור חשב השכר:
-- א. שאילתא המציגה ימים ללא פעילות או ימי פעילות מקוצרים (ערבי חג) לצד הסבר ובקרת שעות.
WITH daily_sales AS (
    SELECT
        DATE(timestamp) AS work_date,
        COUNT(sale_id) AS total_tx,
        ROUND(SUM(total), 0) AS total_revenue,
        MIN(FORMAT_TIMESTAMP('%H:%M', timestamp)) AS first_sale_time,
        MAX(FORMAT_TIMESTAMP('%H:%M', timestamp)) AS last_sale_time
    FROM `bqproj26.Final_Project_2026.log_sales`
    GROUP BY work_date
),
daily_geo AS (
    SELECT
        DATE(timestamp) AS work_date,
        COUNT(*) AS total_pings,
        COUNT(DISTINCT CASE
            WHEN role NOT IN ('repeat_customer', 'one_time_customer', 'not_paying', 'delivery_guy') THEN device_id
        END) AS active_staff_count,
        MIN(FORMAT_TIMESTAMP('%H:%M', timestamp)) AS first_staff_ping,
        MAX(FORMAT_TIMESTAMP('%H:%M', timestamp)) AS last_staff_ping
    FROM `bqproj26.Final_Project_2026.geolocation`
    GROUP BY work_date
)
SELECT
    c.date_key AS date,
    c.hebrew_date,
    c.day_name_he,
    c.event_name,
    c.event_type,
    c.expected_store_status,
    COALESCE(s.total_tx, 0) AS total_tx,
    COALESCE(g.total_pings, 0) AS total_pings,
    COALESCE(g.active_staff_count, 0) AS staff_count,
    COALESCE(s.first_sale_time, 'אין מכירות') AS first_sale,
    COALESCE(s.last_sale_time, 'אין מכירות') AS last_sale,
    COALESCE(g.first_staff_ping, 'אין נוכחות') AS first_ping,
    COALESCE(g.last_staff_ping, 'אין נוכחות') AS last_ping,
    CASE
        WHEN COALESCE(s.total_tx, 0) = 0 AND c.day_of_week_num = 7
            THEN '1. סגור - מנוחת שבת (0 פעילות)'
        WHEN COALESCE(s.total_tx, 0) = 0 AND c.day_of_week_num != 7
            THEN '2. סגור - חג באמצע שבוע (0 פעילות - זכאות לדמי חג בלבד)'
        WHEN c.expected_store_status = 'Open_Short' AND c.day_of_week_num BETWEEN 1 AND 5
            THEN '3. חריגת שכר! ערב חג באמצע שבוע שפעל כיום מלא במקום מקוצר'
    END AS payroll_audit_status
FROM `bqproj26.my_tables.calendar_il_bigquery` c
LEFT JOIN daily_sales s ON c.date_key = s.work_date
LEFT JOIN daily_geo g ON c.date_key = g.work_date
WHERE (COALESCE(s.total_tx, 0) = 0 AND c.day_of_week_num != 7)
   OR (c.expected_store_status = 'Open_Short' AND c.day_of_week_num BETWEEN 1 AND 5)
ORDER BY payroll_audit_status, c.date_key;


-- ב. שאילתא המציגה ימי פעילות גבוהה במיוחד ביחס לממוצע אותו יום בשבוע, עם הסבר מלוח השנה.
WITH daily_metrics AS (
    SELECT
        DATE(s.timestamp) AS work_date,
        COUNT(s.sale_id) AS tx_count,
        ROUND(SUM(s.total), 0) AS daily_revenue
    FROM `bqproj26.Final_Project_2026.log_sales` s
    GROUP BY work_date
),
daily_staff AS (
    SELECT
        DATE(timestamp) AS work_date,
        COUNT(*) AS total_pings,
        COUNT(DISTINCT CASE
            WHEN role NOT IN ('repeat_customer', 'one_time_customer', 'not_paying', 'delivery_guy') THEN device_id
        END) AS staff_count
    FROM `bqproj26.Final_Project_2026.geolocation`
    GROUP BY work_date
),
compared_to_dow AS (
    SELECT
        c.date_key AS date,
        c.hebrew_date,
        c.day_of_week_num,
        c.day_name_he,
        c.event_name,
        c.event_type,
        m.tx_count,
        ROUND(AVG(m.tx_count) OVER(PARTITION BY c.day_of_week_num), 1) AS dow_avg_tx,
        m.daily_revenue,
        ROUND(AVG(m.daily_revenue) OVER(PARTITION BY c.day_of_week_num), 0) AS dow_avg_rev,
        ROUND(((m.daily_revenue - AVG(m.daily_revenue) OVER(PARTITION BY c.day_of_week_num))
               / AVG(m.daily_revenue) OVER(PARTITION BY c.day_of_week_num)) * 100, 1) AS rev_excess_pct,
        ROUND(((m.tx_count - AVG(m.tx_count) OVER(PARTITION BY c.day_of_week_num))
               / AVG(m.tx_count) OVER(PARTITION BY c.day_of_week_num)) * 100, 1) AS tx_excess_pct,
        st.staff_count,
        st.total_pings
    FROM `bqproj26.my_tables.calendar_il_bigquery` c
    JOIN daily_metrics m ON c.date_key = m.work_date
    LEFT JOIN daily_staff st ON c.date_key = st.work_date
)
SELECT
    date,
    hebrew_date,
    day_name_he,
    event_name,
    event_type,
    tx_count,
    dow_avg_tx,
    CONCAT('+', CAST(tx_excess_pct AS STRING), '%') AS tx_jump,
    daily_revenue,
    dow_avg_rev,
    CONCAT('+', CAST(rev_excess_pct AS STRING), '%') AS rev_jump,
    staff_count,
    total_pings
FROM compared_to_dow
WHERE (day_of_week_num BETWEEN 1 AND 4 AND rev_excess_pct >= 15.0)
   OR (day_of_week_num = 6 AND (daily_revenue >= 222000 OR date = '2025-08-29'))
   OR (day_of_week_num = 5 AND daily_revenue >= 230000)
ORDER BY
    CASE WHEN day_of_week_num IN (5, 6) THEN 1 ELSE 2 END,
    daily_revenue DESC;


-- ג. שאילתא המסכמת ימי פעילות נמוכים בהשוואה לימים מקבילים בשבועות אחרים (כולל היום שלפני ואחרי).
WITH daily_sales AS (
    SELECT
        DATE(timestamp) AS work_date,
        COUNT(sale_id) AS tx_count,
        ROUND(SUM(total), 0) AS daily_revenue
    FROM `bqproj26.Final_Project_2026.log_sales`
    GROUP BY work_date
),
enriched_days AS (
    SELECT
        c.date_key AS date,
        c.day_of_week_num,
        c.day_name_he,
        c.event_name,
        c.weather_status_he,
        c.temp_max_c,
        c.rain_mm,
        s.tx_count,
        ROUND(AVG(s.tx_count) OVER(PARTITION BY c.day_of_week_num), 1) AS dow_avg_tx,
        s.daily_revenue,
        ROUND(AVG(s.daily_revenue) OVER(PARTITION BY c.day_of_week_num), 0) AS dow_avg_rev,
        ROUND(((s.daily_revenue - AVG(s.daily_revenue) OVER(PARTITION BY c.day_of_week_num))
               / AVG(s.daily_revenue) OVER(PARTITION BY c.day_of_week_num)) * 100, 1) AS rev_diff_pct,
        -- מה קרה ביום הפתוח הקודם וביום הפתוח הבא
        LAG(CONCAT(CAST(c.date_key AS STRING), ' (', c.event_name, ': ', CAST(ROUND(s.daily_revenue, 0) AS STRING), ' ₪)'))
            OVER(ORDER BY c.date_key) AS prev_open_day_info,
        LEAD(CONCAT(CAST(c.date_key AS STRING), ' (', c.event_name, ': ', CAST(ROUND(s.daily_revenue, 0) AS STRING), ' ₪)'))
            OVER(ORDER BY c.date_key) AS next_open_day_info,
        -- דירוג הימים החלשים ביותר בתוך כל יום בשבוע (1 = הכי חלש באותו יום בשבוע)
        ROW_NUMBER() OVER(PARTITION BY c.day_of_week_num ORDER BY s.daily_revenue ASC) AS weakest_rank_in_dow
    FROM `bqproj26.my_tables.calendar_il_bigquery` c
    JOIN daily_sales s ON c.date_key = s.work_date
)
SELECT
    day_name_he,
    weakest_rank_in_dow AS rank_weakest,
    date,
    event_name,
    weather_status_he,
    rain_mm,
    tx_count,
    dow_avg_tx,
    daily_revenue,
    dow_avg_rev,
    CONCAT(CAST(rev_diff_pct AS STRING), '%') AS drop_vs_dow_avg,
    prev_open_day_info,
    next_open_day_info
FROM enriched_days
WHERE weakest_rank_in_dow <= 3
ORDER BY day_of_week_num, weakest_rank_in_dow;


-- 3.8 שאילתא המציגה את השפעת מזג האוויר על אחוזי השינוי בכמות העסקאות וההכנסות.
WITH daily_compared AS (
    SELECT
        c.date_key,
        c.weather_status_he,
        c.temp_max_c,
        c.rain_mm,
        COUNT(s.sale_id) AS tx_count,
        SUM(s.total) AS daily_rev,
        AVG(COUNT(s.sale_id)) OVER(PARTITION BY c.day_of_week_num) AS dow_avg_tx,
        AVG(SUM(s.total)) OVER(PARTITION BY c.day_of_week_num) AS dow_avg_rev
    FROM `bqproj26.my_tables.calendar_il_bigquery` c
    JOIN `bqproj26.Final_Project_2026.log_sales` s
        ON c.date_key = DATE(s.timestamp)
    GROUP BY c.date_key, c.day_of_week_num, c.weather_status_he, c.temp_max_c, c.rain_mm
)
SELECT
    weather_status_he,
    COUNT(*) AS open_days_count,
    ROUND(AVG(temp_max_c), 1) AS avg_max_temp_c,
    ROUND(AVG(rain_mm), 1) AS avg_rain_mm,
    ROUND(AVG((tx_count - dow_avg_tx) / dow_avg_tx * 100), 1) AS avg_tx_change_pct,
    ROUND(AVG((daily_rev - dow_avg_rev) / dow_avg_rev * 100), 1) AS avg_revenue_change_pct
FROM daily_compared
GROUP BY weather_status_he
ORDER BY avg_revenue_change_pct ASC;


-- ============================================================================
-- חלק 4: מודלים סטטיסטיים ורגרסיה ליניארית
-- ============================================================================

-- 4.1 רגרסיה ראשונה: כמות לקוחות ייחודיים בכל שבוע כתלות במספר השבוע.
-- המטרה: לבדוק האם קיימת צמיחה אורגנית בכמות הלקוחות השבועית ללא מאמץ שיווקי חיצוני.
-- מכיוון שיש קצוות של שבועות חלקיים, סוננו שבועות עם פחות מ-4 ימי פעילות (נותרו 26 שבועות מלאים).
SELECT
    ROW_NUMBER() OVER (ORDER BY week_start_date) AS week_number_X,
    week_start_date,
    open_days_in_week,
    unique_customers_Y
FROM (
    SELECT
        DATE_TRUNC(DATE(timestamp), WEEK(SUNDAY)) AS week_start_date,
        COUNT(DISTINCT DATE(timestamp)) AS open_days_in_week,
        COUNT(DISTINCT device_id) AS unique_customers_Y
    FROM `bqproj26.Final_Project_2026.geolocation`
    WHERE role IN ('repeat_customer', 'one_time_customer')
    GROUP BY week_start_date
)
WHERE open_days_in_week >= 4
ORDER BY week_number_X;


-- 4.2 רגרסיה שנייה: זמן שהייה בסופר (משתנה בלתי תלוי X) והשפעתו על גובה סל הקנייה (משתנה תלוי Y),
-- כולל חישוב המשתנים המחושבים של דקות לשקל ושקלים לדקת שהייה.
SELECT
    CAST(FLOOR(s.dwell_minutes / 10) * 10 AS INT64) AS dwell_bin_10min,
    CONCAT(
        CAST(FLOOR(s.dwell_minutes / 10) * 10 AS STRING),
        '-',
        CAST(FLOOR(s.dwell_minutes / 10) * 10 + 9 AS STRING),
        ' דק׳'
    ) AS dwell_range,
    COUNT(*) AS customers_count,
    ROUND(AVG(s.dwell_minutes), 1) AS actual_avg_dwell,
    ROUND(AVG(s.total), 2) AS avg_basket_ils,
    ROUND(MIN(s.total), 2) AS min_basket_ils,
    ROUND(MAX(s.total), 2) AS max_basket_ils,
    ROUND(AVG(s.dwell_minutes / s.total), 4) AS avg_dwell_per_shekel,
    ROUND(AVG(s.total / s.dwell_minutes), 2) AS avg_shekels_per_minute
FROM `bqproj26.Final_Project_2026.log_sales` s
WHERE s.dwell_minutes IS NOT NULL
GROUP BY 1, 2
ORDER BY dwell_bin_10min;


-- ============================================================================
-- חלק 5: שאילתות ייבוא טבלאות לדשבורד BI ב-Looker Studio
-- ============================================================================

-- 5.1 ייבוא נתונים עבור מסך 1: מדדי מעקב אחר לקוחות וניטור עומסים
SELECT
    g.*,
    EXTRACT(HOUR FROM g.timestamp) AS hour_of_day,
    FORMAT('%02d:00', EXTRACT(HOUR FROM g.timestamp)) AS hour_label,
    c.date_key,
    c.hebrew_date,
    c.day_of_week_num,
    c.day_name_he,
    c.event_name,
    c.event_type,
    c.expected_store_status,
    c.is_rest_day_il,
    c.temp_max_c,
    c.temp_min_c,
    c.rain_mm,
    c.weather_status_he
FROM `bqproj26.Final_Project_2026.geolocation` g
LEFT JOIN `bqproj26.my_tables.calendar_il_bigquery` c
    ON DATE(g.timestamp) = c.date_key;


-- 5.2 ייבוא נתונים עבור מסך 2: סקירת הכנסות ואמצעי תשלום
WITH device_role AS (
    SELECT
        device_id,
        role
    FROM `bqproj26.Final_Project_2026.geolocation`
    WHERE device_id IS NOT NULL
    GROUP BY device_id, role
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY device_id
        ORDER BY COUNT(*) DESC, role
    ) = 1
)
SELECT
    s.*,
    c.date_key,
    c.hebrew_date,
    c.day_of_week_num,
    c.day_name_he,
    c.event_name,
    c.event_type,
    c.expected_store_status,
    c.is_rest_day_il,
    c.temp_max_c,
    c.temp_min_c,
    c.rain_mm,
    c.weather_status_he,
    g.device_id,
    g.role
FROM `bqproj26.Final_Project_2026.log_sales` s
LEFT JOIN `bqproj26.my_tables.calendar_il_bigquery` c
    ON DATE(s.timestamp) = c.date_key
LEFT JOIN device_role g
    ON s.customer_id = g.device_id;


-- 5.3 ייבוא נתונים עבור מסך 3 (א): טבלת תחרות והתרחבות בערים מעל 20,000 תושבים
WITH raw_chains AS (
    -- זיהוי וסיווג שמות הרשתות בכל עיר
    SELECT
        TRIM(s.city) AS city,
        CASE
            WHEN REGEXP_CONTAINS(s.name, r'(?i)שופרסל|יש חסד|יש בשכונה|Shufersal') THEN 'שופרסל / יש'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)רמי לוי') THEN 'רמי לוי'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)אושר עד') THEN 'אושר עד'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)יינות ביתן|מגה') THEN 'יינות ביתן / מגה'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)יוחננוף') THEN 'יוחננוף'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)מחסני השוק') THEN 'מחסני השוק'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)ויקטורי') THEN 'ויקטורי'
            WHEN REGEXP_CONTAINS(s.name, r'(?i)AM:PM') THEN 'AM:PM'
            WHEN s.name IS NULL OR TRIM(s.name) = '' THEN 'ללא שם (מכולת/פרטי)'
            ELSE 'סופר פרטי / אחר'
        END AS chain_name
    FROM `bqproj26.Final_Project_2026.supermarkets_il` s
),
chain_counts AS (
    SELECT
        city,
        chain_name,
        COUNT(*) AS branches_count
    FROM raw_chains
    GROUP BY city, chain_name
),
ranked_chains AS (
    SELECT
        city,
        chain_name,
        branches_count,
        -- דירוג למציאת הרשת הארצית הדומיננטית ביותר בעיר
        ROW_NUMBER() OVER(
            PARTITION BY city
            ORDER BY
                CASE WHEN chain_name NOT IN ('ללא שם (מכולת/פרטי)', 'סופר פרטי / אחר') THEN 1 ELSE 2 END,
                branches_count DESC
        ) AS rank_in_city,
        CONCAT(chain_name, ' (', CAST(branches_count AS STRING), ')') AS chain_summary_item
    FROM chain_counts
),
city_competition AS (
    -- איחוד כל המידע התחרותי לשורה אחת בלבד לכל עיר (מונע כפילויות!)
    SELECT
        city,
        MAX(CASE WHEN rank_in_city = 1 THEN chain_name END) AS dominant_chain,
        MAX(CASE WHEN rank_in_city = 1 THEN branches_count END) AS dominant_chain_branches,
        STRING_AGG(chain_summary_item, ', ' ORDER BY branches_count DESC) AS all_chains_in_city
    FROM ranked_chains
    GROUP BY city
)
SELECT
    l.city_name,
    l.total_population,
    COUNT(s.id) AS supermarkets_count,
    -- כמות תושבים על כל סופר (אם יש 0 סופרים - כל האוכלוסייה ללא מענה)
    COALESCE(ROUND(l.total_population / NULLIF(COUNT(s.id), 0), 0), l.total_population) AS people_per_supermarket,
    -- מדד סופרים ל-10,000 נפש
    ROUND(COUNT(s.id) * 10000.0 / l.total_population, 2) AS supermarkets_per_10k,
    -- תמונת התחרות בעיר
    COALESCE(c.dominant_chain, 'אין סופרים בעיר') AS dominant_chain,
    COALESCE(c.dominant_chain_branches, 0) AS dominant_chain_branches,
    COALESCE(c.all_chains_in_city, 'אין מתחרים ממופים') AS competitors_breakdown,
    -- המלצת תכל'ס להנהלה (Executive Decision)
    CASE
        WHEN COUNT(s.id) = 0
            THEN '1. הזדמנות ואקום: 0 סופרים בעיר (אפס תחרות רשתות)'
        WHEN ROUND(COUNT(s.id) * 10000.0 / l.total_population, 2) < 1.0
         AND COALESCE(c.dominant_chain_branches, 0) <= 1
            THEN '2. אור ירוק לפתיחה: מחסור חמור בסופרים + אין רשת חוסמת!'
        WHEN ROUND(COUNT(s.id) * 10000.0 / l.total_population, 2) < 1.0
         AND c.dominant_chain NOT IN ('ללא שם (מכולת/פרטי)', 'סופר פרטי / אחר')
         AND c.dominant_chain_branches >= 3
            THEN '3. מלכודת תחרות (לא לפתוח): מעט סופרים אך רשת חזקה שולטת בעיר'
        WHEN ROUND(COUNT(s.id) * 10000.0 / l.total_population, 2) >= 3.5
            THEN '5. שוק רווי וצפוף (לא לפתוח): עודף סופרים ביחס לתושבים'
        ELSE '4. שוק מאוזן / תחרות בינונית'
    END AS executive_recommendation
FROM `bqproj26.Final_Project_2026.Lamas_Israel_2026` l
LEFT JOIN `bqproj26.Final_Project_2026.supermarkets_il` s
    ON TRIM(l.city_name) = TRIM(s.city)
LEFT JOIN city_competition c
    ON TRIM(l.city_name) = c.city
WHERE l.total_population >= 20000
GROUP BY
    l.city_name,
    l.total_population,
    c.dominant_chain,
    c.dominant_chain_branches,
    c.all_chains_in_city
ORDER BY
    supermarkets_per_10k ASC,
    l.total_population DESC;


-- 5.4 ייבוא נתונים עבור מסך 3 (ב): מפת סופרים ואוכלוסייה בכל רחבי הארץ
SELECT
    p.city_name AS city,
    p.total_population AS population,
    COUNT(s.id) AS supermarket_count
FROM `bqproj26.Final_Project_2026.Lamas_Israel_2026` AS p
LEFT JOIN `bqproj26.Final_Project_2026.supermarkets_il` AS s
    ON p.city_name = s.city
GROUP BY
    p.city_name,
    p.total_population
ORDER BY
    supermarket_count DESC,
    population DESC;
