-- Lakehouse External Function 注册 SQL
-- 对应 01_source/udf/ 下的 Python 和 Java UDF
--
-- 前置条件（需管理员完成）：
--   1. 开通云函数服务（阿里云 FC / 腾讯云 SCF）
--   2. 配置 RAM/CAM 角色，授权 Lakehouse 调用云函数
--   3. 创建 API Connection（替换下方 <...> 占位符）
--
-- 打包上传（在终端执行）：
--   zip -rq text_analytics.zip text_analytics.py
--   javac StringUtils.java && jar cf stringutils.jar com/
--   PUT '/path/to/text_analytics.zip' TO USER VOLUME;
--   PUT '/path/to/stringutils.jar' TO USER VOLUME;

-- =============================================
-- 1. 创建 API Connection（阿里云 FC 示例）
-- =============================================

CREATE API CONNECTION IF NOT EXISTS ecommerce_fc_conn
    TYPE CLOUD_FUNCTION
    PROVIDER = 'aliyun'
    REGION = 'cn-shanghai'
    ROLE_ARN = '<acs:ram::ACCOUNT_ID:role/CzUDFRole>'
    NAMESPACE = 'default'
    CODE_BUCKET = '<your-oss-bucket>';

-- =============================================
-- 2. Python UDF — text_analytics
-- =============================================

CREATE EXTERNAL FUNCTION IF NOT EXISTS ecommerce.text_sentiment(text STRING)
    RETURNS STRING
    AS 'text_analytics.TextSentiment'
    USING FILE = 'volume:user://~/text_analytics.zip'
    CONNECTION = ecommerce_fc_conn
    WITH PROPERTIES ('remote.udf.api' = 'python3.mc.v0')
    COMMENT '情感分析：返回 positive/negative/neutral';

CREATE EXTERNAL FUNCTION IF NOT EXISTS ecommerce.text_keywords(text STRING, top_n BIGINT)
    RETURNS STRING
    AS 'text_analytics.TextKeywords'
    USING FILE = 'volume:user://~/text_analytics.zip'
    CONNECTION = ecommerce_fc_conn
    WITH PROPERTIES ('remote.udf.api' = 'python3.mc.v0')
    COMMENT '提取关键词，返回逗号分隔的 top-N 词';

CREATE EXTERNAL FUNCTION IF NOT EXISTS ecommerce.text_similarity(text1 STRING, text2 STRING)
    RETURNS DOUBLE
    AS 'text_analytics.TextSimilarity'
    USING FILE = 'volume:user://~/text_analytics.zip'
    CONNECTION = ecommerce_fc_conn
    WITH PROPERTIES ('remote.udf.api' = 'python3.mc.v0')
    COMMENT '余弦相似度（词袋模型），返回 0.0-1.0';

CREATE EXTERNAL FUNCTION IF NOT EXISTS ecommerce.text_word_count(text STRING)
    RETURNS BIGINT
    AS 'text_analytics.TextWordCount'
    USING FILE = 'volume:user://~/text_analytics.zip'
    CONNECTION = ecommerce_fc_conn
    WITH PROPERTIES ('remote.udf.api' = 'python3.mc.v0')
    COMMENT '统计有效词数（去除停用词）';

CREATE EXTERNAL FUNCTION IF NOT EXISTS ecommerce.text_language_detect(text STRING)
    RETURNS STRING
    AS 'text_analytics.TextLanguageDetect'
    USING FILE = 'volume:user://~/text_analytics.zip'
    CONNECTION = ecommerce_fc_conn
    WITH PROPERTIES ('remote.udf.api' = 'python3.mc.v0')
    COMMENT '语言检测：返回 zh/ja/ko/en/unknown';

CREATE EXTERNAL FUNCTION IF NOT EXISTS ecommerce.text_clean(text STRING, mode STRING)
    RETURNS STRING
    AS 'text_analytics.TextClean'
    USING FILE = 'volume:user://~/text_analytics.zip'
    CONNECTION = ecommerce_fc_conn
    WITH PROPERTIES ('remote.udf.api' = 'python3.mc.v0')
    COMMENT '文本清洗：去除 HTML/邮箱/电话（mode: html/email/phone/all）';

-- =============================================
-- 3. Java UDF — StringUtils
-- =============================================

CREATE EXTERNAL FUNCTION IF NOT EXISTS ecommerce.string_utils(input STRING, mode STRING)
    RETURNS STRING
    AS 'com.clickzetta.udf.StringUtils'
    USING FILE = 'volume:user://~/stringutils.jar'
    CONNECTION = ecommerce_fc_conn
    WITH PROPERTIES ('remote.udf.api' = 'java.mc.v0')
    COMMENT '字符串处理：title_case/extract_numbers/mask_email/validate_email/slug/initials/word_count/reverse/remove_special';

-- =============================================
-- 4. 使用示例
-- =============================================

-- 情感分析（调用时必须带 schema 前缀）
-- SELECT customer_id, ecommerce.text_sentiment(review_text) AS sentiment
-- FROM ecommerce.customer_reviews;

-- 关键词提取
-- SELECT product_id, ecommerce.text_keywords(description, 5) AS keywords
-- FROM ecommerce.products;

-- 字符串处理
-- SELECT ecommerce.string_utils('john smith', 'title_case') AS name;
-- SELECT ecommerce.string_utils('john.doe@example.com', 'mask_email') AS masked;

-- =============================================
-- 5. 删除函数（用 DROP FUNCTION，不是 DROP EXTERNAL FUNCTION）
-- =============================================

-- DROP FUNCTION IF EXISTS ecommerce.text_sentiment;
-- DROP FUNCTION IF EXISTS ecommerce.string_utils;
