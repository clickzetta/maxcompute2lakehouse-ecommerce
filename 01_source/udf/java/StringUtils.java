package com.alibaba.dataworks.udf;

import com.aliyun.odps.udf.UDF;
import com.aliyun.odps.udf.annotation.Resolve;
import java.util.regex.Pattern;
import java.util.regex.Matcher;

/**
 * StringUtils UDF for MaxCompute
 * Provides common string manipulation functions for data processing
 * 
 * Usage Examples:
 * SELECT string_clean('  Hello World  ') as cleaned; -- 'Hello World'
 * SELECT string_extract_numbers('Order123Items456') as numbers; -- '123456'
 * SELECT string_mask_email('user@example.com') as masked; -- 'u***@e***.com'
 */
@Resolve({"string->string", "string,string->string"})
public class StringUtils extends UDF {
    
    private static final Pattern EMAIL_PATTERN = 
        Pattern.compile("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$");
    private static final Pattern PHONE_PATTERN = 
        Pattern.compile("(\\+?\\d{1,3})?[-.\\s]?\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}");
    private static final Pattern NUMBERS_PATTERN = 
        Pattern.compile("\\d+");
    
    /**
     * Clean and normalize string by trimming, converting to proper case
     */
    public String evaluate(String input) {
        if (input == null || input.trim().isEmpty()) {
            return null;
        }
        
        // Trim whitespace and normalize internal spacing
        String cleaned = input.trim().replaceAll("\\s+", " ");
        
        // Convert to proper case (first letter of each word capitalized)
        StringBuilder result = new StringBuilder();
        boolean capitalizeNext = true;
        
        for (char c : cleaned.toCharArray()) {
            if (Character.isLetter(c)) {
                if (capitalizeNext) {
                    result.append(Character.toUpperCase(c));
                    capitalizeNext = false;
                } else {
                    result.append(Character.toLowerCase(c));
                }
            } else {
                result.append(c);
                if (Character.isWhitespace(c)) {
                    capitalizeNext = true;
                }
            }
        }
        
        return result.toString();
    }
    
    /**
     * Perform specific string operations based on operation type
     */
    public String evaluate(String input, String operation) {
        if (input == null) {
            return null;
        }
        
        if (operation == null) {
            return evaluate(input); // Default cleaning
        }
        
        switch (operation.toLowerCase()) {
            case "clean":
                return evaluate(input);
                
            case "upper":
                return input.toUpperCase();
                
            case "lower":
                return input.toLowerCase();
                
            case "extract_numbers":
                return extractNumbers(input);
                
            case "extract_letters":
                return extractLetters(input);
                
            case "mask_email":
                return maskEmail(input);
                
            case "mask_phone":
                return maskPhone(input);
                
            case "validate_email":
                return isValidEmail(input) ? "valid" : "invalid";
                
            case "validate_phone":
                return isValidPhone(input) ? "valid" : "invalid";
                
            case "remove_special":
                return input.replaceAll("[^a-zA-Z0-9\\s]", "");
                
            case "slug":
                return createSlug(input);
                
            case "initials":
                return getInitials(input);
                
            case "reverse":
                return new StringBuilder(input).reverse().toString();
                
            case "word_count":
                return String.valueOf(input.trim().split("\\s+").length);
                
            case "char_count":
                return String.valueOf(input.length());
                
            default:
                return input; // Return original if operation not recognized
        }
    }
    
    /**
     * Extract all numbers from string and concatenate them
     */
    private String extractNumbers(String input) {
        StringBuilder numbers = new StringBuilder();
        Matcher matcher = NUMBERS_PATTERN.matcher(input);
        while (matcher.find()) {
            numbers.append(matcher.group());
        }
        return numbers.length() > 0 ? numbers.toString() : null;
    }
    
    /**
     * Extract only letters from string
     */
    private String extractLetters(String input) {
        return input.replaceAll("[^a-zA-Z]", "");
    }
    
    /**
     * Mask email address for privacy (keep first and last character of username and domain)
     */
    private String maskEmail(String email) {
        if (!isValidEmail(email)) {
            return email;
        }
        
        String[] parts = email.split("@");
        String username = parts[0];
        String domain = parts[1];
        
        String maskedUsername = maskString(username);
        String maskedDomain = maskString(domain.split("\\.")[0]) + "." + domain.split("\\.")[1];
        
        return maskedUsername + "@" + maskedDomain;
    }
    
    /**
     * Mask phone number (show only last 4 digits)
     */
    private String maskPhone(String phone) {
        if (!isValidPhone(phone)) {
            return phone;
        }
        
        String numbersOnly = phone.replaceAll("[^0-9]", "");
        if (numbersOnly.length() < 4) {
            return phone;
        }
        
        String lastFour = numbersOnly.substring(numbersOnly.length() - 4);
        String masked = "*".repeat(numbersOnly.length() - 4) + lastFour;
        
        return masked;
    }
    
    /**
     * Helper method to mask string (show first and last character, mask middle)
     */
    private String maskString(String str) {
        if (str.length() <= 2) {
            return "*".repeat(str.length());
        }
        
        return str.charAt(0) + "*".repeat(str.length() - 2) + str.charAt(str.length() - 1);
    }
    
    /**
     * Validate email format
     */
    private boolean isValidEmail(String email) {
        return EMAIL_PATTERN.matcher(email).matches();
    }
    
    /**
     * Validate phone format
     */
    private boolean isValidPhone(String phone) {
        return PHONE_PATTERN.matcher(phone).find();
    }
    
    /**
     * Create URL-friendly slug from string
     */
    private String createSlug(String input) {
        return input.toLowerCase()
                   .replaceAll("[^a-z0-9\\s-]", "")
                   .replaceAll("\\s+", "-")
                   .replaceAll("-+", "-")
                   .replaceAll("^-|-$", "");
    }
    
    /**
     * Get initials from name
     */
    private String getInitials(String name) {
        StringBuilder initials = new StringBuilder();
        String[] words = name.trim().split("\\s+");
        
        for (String word : words) {
            if (!word.isEmpty()) {
                initials.append(Character.toUpperCase(word.charAt(0)));
            }
        }
        
        return initials.toString();
    }
}

/*
Compilation Instructions:
1. Ensure you have MaxCompute SDK in your classpath
2. Compile: javac -cp "odps-sdk-udf-0.47.4-public.jar" StringUtils.java
3. Package: jar cf stringutils.jar StringUtils.class
4. Upload to MaxCompute:
   ADD JAR stringutils.jar;
   CREATE FUNCTION string_utils AS 'com.alibaba.dataworks.udf.StringUtils' USING 'stringutils.jar';

Usage Examples in MaxCompute SQL:
-- Basic cleaning
SELECT string_utils('  john smith  ') as cleaned_name;  -- 'John Smith'

-- Extract numbers
SELECT string_utils('Order123Item456', 'extract_numbers') as order_nums;  -- '123456'

-- Mask email
SELECT string_utils('john.doe@example.com', 'mask_email') as masked;  -- 'j*****e@e***.com'

-- Validate email
SELECT string_utils('invalid-email', 'validate_email') as is_valid;  -- 'invalid'

-- Create slug
SELECT string_utils('Hello World!', 'slug') as url_slug;  -- 'hello-world'

-- Get initials
SELECT string_utils('John Michael Smith', 'initials') as initials;  -- 'JMS'

-- Word count
SELECT string_utils('Hello world example', 'word_count') as words;  -- '3'
*/