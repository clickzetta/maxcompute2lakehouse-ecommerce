# -*- coding: utf-8 -*-
"""
text_analytics.py — Lakehouse External Function 版本
对应 01_source/udf/python/text_analytics.py

迁移说明：
  MaxCompute UDF 在 MaxCompute 引擎内直接执行。
  Lakehouse External Function 需要部署到云函数服务（阿里云 FC / 腾讯云 SCF / AWS Lambda），
  通过 API Connection 调用。

部署步骤：
  1. 打包：zip -rq text_analytics.zip text_analytics.py
  2. 上传：PUT '/path/to/text_analytics.zip' TO USER VOLUME;
  3. 创建 API Connection（见 02_migration/02_dataworks_to_studio.md）
  4. 创建 External Function（见本文件末尾的 SQL）

Lakehouse External Function 规范：
  - 每个函数对应一个类，实现 evaluate() 方法
  - 类型注解通过 @annotate("input_type->return_type") 声明
  - 支持类型：string, bigint, double, boolean, datetime
"""

try:
    from cz.udf import annotate
except ImportError:
    # 本地开发时 cz.udf 不可用，用空装饰器代替
    def annotate(_):
        def decorator(cls):
            return cls
        return decorator

import re
import math
from collections import Counter


@annotate("string->string")
class TextSentiment(object):
    """简单情感分析：返回 positive / negative / neutral"""

    POSITIVE = {'good', 'great', 'excellent', 'amazing', 'love', 'best',
                'wonderful', 'fantastic', 'happy', 'satisfied', 'perfect'}
    NEGATIVE = {'bad', 'terrible', 'awful', 'hate', 'worst', 'horrible',
                'disappointed', 'poor', 'broken', 'useless', 'waste'}

    def evaluate(self, text):
        if text is None:
            return 'neutral'
        words = set(re.findall(r'\b\w+\b', text.lower()))
        pos = len(words & self.POSITIVE)
        neg = len(words & self.NEGATIVE)
        if pos > neg:
            return 'positive'
        elif neg > pos:
            return 'negative'
        return 'neutral'


@annotate("string,bigint->string")
class TextKeywords(object):
    """提取关键词，返回逗号分隔的 top-N 词"""

    STOPWORDS = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at',
                 'to', 'for', 'of', 'with', 'by', 'is', 'are', 'was', 'were',
                 'be', 'been', 'have', 'has', 'had', 'do', 'does', 'did',
                 'will', 'would', 'could', 'should', 'may', 'might', 'this',
                 'that', 'these', 'those', 'it', 'its', 'i', 'you', 'he',
                 'she', 'we', 'they', 'not', 'no', 'from', 'as', 'into'}

    def evaluate(self, text, top_n):
        if text is None:
            return ''
        n = int(top_n) if top_n else 5
        words = [w for w in re.findall(r'\b[a-z]{3,}\b', text.lower())
                 if w not in self.STOPWORDS]
        freq = Counter(words)
        return ','.join(w for w, _ in freq.most_common(n))


@annotate("string,string->double")
class TextSimilarity(object):
    """余弦相似度（词袋模型）"""

    def _vectorize(self, text):
        words = re.findall(r'\b\w+\b', text.lower())
        return Counter(words)

    def _cosine(self, v1, v2):
        common = set(v1) & set(v2)
        if not common:
            return 0.0
        dot = sum(v1[w] * v2[w] for w in common)
        mag1 = math.sqrt(sum(c * c for c in v1.values()))
        mag2 = math.sqrt(sum(c * c for c in v2.values()))
        if mag1 == 0 or mag2 == 0:
            return 0.0
        return dot / (mag1 * mag2)

    def evaluate(self, text1, text2):
        if text1 is None or text2 is None:
            return 0.0
        return round(self._cosine(self._vectorize(text1), self._vectorize(text2)), 4)


@annotate("string->bigint")
class TextWordCount(object):
    """统计有效词数（去除停用词）"""

    STOPWORDS = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at',
                 'to', 'for', 'of', 'with', 'by', 'is', 'are', 'was'}

    def evaluate(self, text):
        if text is None:
            return 0
        words = [w for w in re.findall(r'\b\w+\b', text.lower())
                 if w not in self.STOPWORDS]
        return len(words)


@annotate("string->string")
class TextLanguageDetect(object):
    """简单语言检测：中文 / 日文 / 韩文 / 英文"""

    def evaluate(self, text):
        if text is None:
            return 'unknown'
        if re.search(r'[一-鿿]', text):
            return 'zh'
        if re.search(r'[぀-ゟ゠-ヿ]', text):
            return 'ja'
        if re.search(r'[가-힯]', text):
            return 'ko'
        return 'en'


@annotate("string,string->string")
class TextClean(object):
    """文本清洗：去除 HTML、邮箱、电话等"""

    def evaluate(self, text, mode):
        if text is None:
            return None
        m = (mode or 'all').lower()
        result = text
        if m in ('html', 'all'):
            result = re.sub(r'<[^>]+>', ' ', result)
        if m in ('email', 'all'):
            result = re.sub(r'\S+@\S+\.\S+', '', result)
        if m in ('phone', 'all'):
            result = re.sub(r'\b[\d\-\(\)\+\s]{7,}\b', '', result)
        result = re.sub(r'\s+', ' ', result).strip()
        return result
