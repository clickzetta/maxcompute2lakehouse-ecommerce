#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Text Analytics UDF for MaxCompute
Provides advanced text processing and natural language processing functions

Dependencies:
- No external libraries required (uses only Python standard library)
- For production use, consider adding nltk or spacy support

Usage Examples:
SELECT text_sentiment('This product is amazing!') as sentiment;
SELECT text_keywords('The quick brown fox jumps over the lazy dog') as keywords;
SELECT text_similarity('hello world', 'hello earth') as similarity;
"""

from odps.udf import annotate
from odps.udf import BaseUDF
import re
import math
from collections import Counter


@annotate("string->string")
class TextSentiment(BaseUDF):
    """
    Simple sentiment analysis using keyword-based approach
    Returns: positive, negative, or neutral
    """
    
    def __init__(self):
        # Simple sentiment dictionaries
        self.positive_words = {
            'good', 'great', 'excellent', 'amazing', 'wonderful', 'fantastic',
            'awesome', 'perfect', 'love', 'like', 'best', 'brilliant',
            'outstanding', 'superb', 'magnificent', 'terrific', 'marvelous',
            'happy', 'pleased', 'satisfied', 'delighted', 'thrilled'
        }
        
        self.negative_words = {
            'bad', 'terrible', 'awful', 'horrible', 'disgusting', 'hate',
            'dislike', 'worst', 'pathetic', 'useless', 'disappointing',
            'frustrated', 'angry', 'sad', 'upset', 'annoyed', 'furious',
            'poor', 'inferior', 'defective', 'broken', 'failed'
        }
        
        # Negation words that can flip sentiment
        self.negation_words = {
            'not', 'no', 'never', 'nothing', 'nowhere', 'nobody',
            'none', 'neither', 'nor', 'cannot', 'cant', 'wont', 'dont'
        }
    
    def evaluate(self, text):
        if not text:
            return 'neutral'
        
        # Clean and tokenize text
        words = re.findall(r'\b\w+\b', text.lower())
        
        positive_score = 0
        negative_score = 0
        negate = False
        
        for word in words:
            # Check for negation
            if word in self.negation_words:
                negate = True
                continue
            
            # Score sentiment
            if word in self.positive_words:
                if negate:
                    negative_score += 1
                else:
                    positive_score += 1
            elif word in self.negative_words:
                if negate:
                    positive_score += 1
                else:
                    negative_score += 1
            
            # Reset negation after 2 words
            if negate:
                negate = False
        
        # Determine overall sentiment
        if positive_score > negative_score:
            return 'positive'
        elif negative_score > positive_score:
            return 'negative'
        else:
            return 'neutral'


@annotate("string->string")
class TextKeywords(BaseUDF):
    """
    Extract keywords from text using TF-IDF-like scoring
    Returns comma-separated list of top keywords
    """
    
    def __init__(self):
        # Common stop words to exclude
        self.stop_words = {
            'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to',
            'for', 'of', 'with', 'by', 'from', 'up', 'about', 'into',
            'through', 'during', 'before', 'after', 'above', 'below',
            'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have',
            'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
            'should', 'may', 'might', 'must', 'can', 'this', 'that',
            'these', 'those', 'i', 'you', 'he', 'she', 'it', 'we', 'they'
        }
    
    def evaluate(self, text):
        if not text:
            return ''
        
        # Clean and tokenize
        words = re.findall(r'\b\w+\b', text.lower())
        
        # Filter out stop words and short words
        filtered_words = [
            word for word in words 
            if word not in self.stop_words and len(word) > 2
        ]
        
        if not filtered_words:
            return ''
        
        # Count word frequencies
        word_freq = Counter(filtered_words)
        
        # Simple keyword scoring (frequency * length)
        scored_words = [
            (word, freq * len(word)) 
            for word, freq in word_freq.items()
        ]
        
        # Sort by score and return top 5
        top_keywords = sorted(scored_words, key=lambda x: x[1], reverse=True)[:5]
        
        return ','.join([word for word, score in top_keywords])


@annotate("string,string->double")
class TextSimilarity(BaseUDF):
    """
    Calculate similarity between two texts using cosine similarity
    Returns value between 0 (no similarity) and 1 (identical)
    """
    
    def evaluate(self, text1, text2):
        if not text1 or not text2:
            return 0.0
        
        # Tokenize both texts
        words1 = set(re.findall(r'\b\w+\b', text1.lower()))
        words2 = set(re.findall(r'\b\w+\b', text2.lower()))
        
        # Calculate Jaccard similarity (intersection over union)
        intersection = len(words1.intersection(words2))
        union = len(words1.union(words2))
        
        if union == 0:
            return 0.0
        
        return float(intersection) / float(union)


@annotate("string->bigint")
class TextWordCount(BaseUDF):
    """
    Count words in text (excluding stop words)
    """
    
    def __init__(self):
        self.stop_words = {
            'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to',
            'for', 'of', 'with', 'by', 'from', 'is', 'are', 'was', 'were'
        }
    
    def evaluate(self, text):
        if not text:
            return 0
        
        words = re.findall(r'\b\w+\b', text.lower())
        meaningful_words = [
            word for word in words 
            if word not in self.stop_words and len(word) > 2
        ]
        
        return len(meaningful_words)


@annotate("string->string")
class TextLanguageDetect(BaseUDF):
    """
    Simple language detection based on character patterns
    Returns: english, chinese, japanese, korean, arabic, or unknown
    """
    
    def evaluate(self, text):
        if not text:
            return 'unknown'
        
        # Count different character types
        latin_chars = len(re.findall(r'[a-zA-Z]', text))
        chinese_chars = len(re.findall(r'[\u4e00-\u9fff]', text))
        japanese_chars = len(re.findall(r'[\u3040-\u309f\u30a0-\u30ff]', text))
        korean_chars = len(re.findall(r'[\uac00-\ud7af]', text))
        arabic_chars = len(re.findall(r'[\u0600-\u06ff]', text))
        
        total_chars = len(text)
        
        # Calculate percentages
        if total_chars == 0:
            return 'unknown'
        
        latin_pct = latin_chars / total_chars
        chinese_pct = chinese_chars / total_chars
        japanese_pct = japanese_chars / total_chars
        korean_pct = korean_chars / total_chars
        arabic_pct = arabic_chars / total_chars
        
        # Determine language based on highest percentage
        if latin_pct > 0.7:
            return 'english'
        elif chinese_pct > 0.3:
            return 'chinese'
        elif japanese_pct > 0.3:
            return 'japanese'
        elif korean_pct > 0.3:
            return 'korean'
        elif arabic_pct > 0.3:
            return 'arabic'
        else:
            return 'unknown'


@annotate("string,string->string")
class TextClean(BaseUDF):
    """
    Clean text based on specified cleaning type
    Types: html, email, phone, url, punctuation, numbers, whitespace
    """
    
    def evaluate(self, text, clean_type):
        if not text:
            return text
        
        if not clean_type:
            return text
        
        result = text
        
        if clean_type == 'html':
            # Remove HTML tags
            result = re.sub(r'<[^>]+>', '', result)
            # Decode common HTML entities
            result = result.replace('&amp;', '&')
            result = result.replace('&lt;', '<')
            result = result.replace('&gt;', '>')
            result = result.replace('&quot;', '"')
            result = result.replace('&#39;', "'")
        
        elif clean_type == 'email':
            # Remove email addresses
            result = re.sub(r'\S+@\S+', '', result)
        
        elif clean_type == 'phone':
            # Remove phone numbers
            result = re.sub(r'(\+?\d{1,3})?[\s.-]?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}', '', result)
        
        elif clean_type == 'url':
            # Remove URLs
            result = re.sub(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', '', result)
        
        elif clean_type == 'punctuation':
            # Remove punctuation except spaces
            result = re.sub(r'[^\w\s]', '', result)
        
        elif clean_type == 'numbers':
            # Remove numbers
            result = re.sub(r'\d+', '', result)
        
        elif clean_type == 'whitespace':
            # Normalize whitespace
            result = re.sub(r'\s+', ' ', result).strip()
        
        elif clean_type == 'all':
            # Apply all cleaning operations
            result = re.sub(r'<[^>]+>', '', result)  # HTML
            result = re.sub(r'\S+@\S+', '', result)  # Email
            result = re.sub(r'(\+?\d{1,3})?[\s.-]?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}', '', result)  # Phone
            result = re.sub(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', '', result)  # URL
            result = re.sub(r'[^\w\s]', '', result)  # Punctuation
            result = re.sub(r'\s+', ' ', result).strip()  # Whitespace
        
        return result


"""
Deployment Instructions:

1. Save this file as text_analytics.py
2. Upload to MaxCompute as a Python resource:
   ADD PY text_analytics.py;

3. Create UDF functions:
   CREATE FUNCTION text_sentiment AS 'text_analytics.TextSentiment' USING 'text_analytics.py';
   CREATE FUNCTION text_keywords AS 'text_analytics.TextKeywords' USING 'text_analytics.py';
   CREATE FUNCTION text_similarity AS 'text_analytics.TextSimilarity' USING 'text_analytics.py';
   CREATE FUNCTION text_word_count AS 'text_analytics.TextWordCount' USING 'text_analytics.py';
   CREATE FUNCTION text_language_detect AS 'text_analytics.TextLanguageDetect' USING 'text_analytics.py';
   CREATE FUNCTION text_clean AS 'text_analytics.TextClean' USING 'text_analytics.py';

Usage Examples:

-- Sentiment analysis
SELECT 
    customer_id,
    review_text,
    text_sentiment(review_text) as sentiment
FROM customer_reviews;

-- Extract keywords from product descriptions
SELECT 
    product_id,
    description,
    text_keywords(description) as keywords
FROM products;

-- Calculate similarity between product descriptions
SELECT 
    p1.product_id as product1,
    p2.product_id as product2,
    text_similarity(p1.description, p2.description) as similarity
FROM products p1
CROSS JOIN products p2
WHERE p1.product_id < p2.product_id
  AND text_similarity(p1.description, p2.description) > 0.5;

-- Count meaningful words in customer feedback
SELECT 
    feedback_id,
    text_word_count(feedback_text) as word_count,
    text_language_detect(feedback_text) as language
FROM customer_feedback;

-- Clean text data
SELECT 
    text_clean('<p>Contact us at support@company.com or call 123-456-7890</p>', 'all') as cleaned;
-- Result: 'Contact us at or call'
"""