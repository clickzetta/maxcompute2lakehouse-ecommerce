package com.clickzetta.udf;

/**
 * StringUtils.java — Lakehouse External Function 版本
 * 对应 01_source/udf/java/StringUtils.java
 *
 * 迁移说明：
 *   MaxCompute Java UDF 继承 com.aliyun.odps.udf.UDF，在 MaxCompute 引擎内执行。
 *   Lakehouse External Function 需要部署到云函数服务，通过 API Connection 调用。
 *   包名从 com.alibaba.dataworks.udf 改为 com.clickzetta.udf。
 *
 * 部署步骤：
 *   1. 编译：javac -cp "." StringUtils.java
 *   2. 打包：jar cf stringutils.jar com/clickzetta/udf/StringUtils.class
 *   3. 上传：PUT '/path/to/stringutils.jar' TO USER VOLUME;
 *   4. 创建 External Function（见本文件末尾的 SQL）
 *
 * Lakehouse External Function Java 规范：
 *   - 实现 evaluate() 方法（替代 MaxCompute 的 evaluate()）
 *   - 通过 @Resolve 注解声明参数类型（与 MaxCompute 相同）
 *   - 返回 null 表示 NULL 值
 */

import java.util.regex.Pattern;
import java.util.regex.Matcher;

public class StringUtils {

    /**
     * 字符串处理主函数
     * @param input  输入字符串
     * @param mode   处理模式（可选，默认 title_case）
     * @return 处理结果
     */
    public String evaluate(String input, String mode) {
        if (input == null) return null;
        String m = (mode == null) ? "title_case" : mode.toLowerCase();

        switch (m) {
            case "title_case":
                return toTitleCase(input.trim());
            case "extract_numbers":
                return extractNumbers(input);
            case "mask_email":
                return maskEmail(input);
            case "validate_email":
                return validateEmail(input) ? "valid" : "invalid";
            case "slug":
                return toSlug(input);
            case "initials":
                return getInitials(input);
            case "word_count":
                return String.valueOf(countWords(input));
            case "reverse":
                return new StringBuilder(input).reverse().toString();
            case "remove_special":
                return input.replaceAll("[^a-zA-Z0-9\\s]", "").trim();
            default:
                return toTitleCase(input.trim());
        }
    }

    /** 单参数重载（默认 title_case） */
    public String evaluate(String input) {
        return evaluate(input, "title_case");
    }

    private String toTitleCase(String s) {
        if (s == null || s.isEmpty()) return s;
        String[] words = s.toLowerCase().split("\\s+");
        StringBuilder sb = new StringBuilder();
        for (String w : words) {
            if (!w.isEmpty()) {
                sb.append(Character.toUpperCase(w.charAt(0)))
                  .append(w.substring(1))
                  .append(' ');
            }
        }
        return sb.toString().trim();
    }

    private String extractNumbers(String s) {
        return s.replaceAll("[^0-9]", "");
    }

    private String maskEmail(String email) {
        if (!validateEmail(email)) return email;
        int at = email.indexOf('@');
        String local = email.substring(0, at);
        String domain = email.substring(at + 1);
        String maskedLocal = local.charAt(0)
            + "*".repeat(Math.max(0, local.length() - 2))
            + (local.length() > 1 ? String.valueOf(local.charAt(local.length() - 1)) : "");
        int dot = domain.lastIndexOf('.');
        String domainName = domain.substring(0, dot);
        String tld = domain.substring(dot);
        String maskedDomain = domainName.charAt(0)
            + "*".repeat(Math.max(0, domainName.length() - 1))
            + tld;
        return maskedLocal + "@" + maskedDomain;
    }

    private boolean validateEmail(String email) {
        return email != null &&
               Pattern.matches("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", email);
    }

    private String toSlug(String s) {
        return s.toLowerCase()
                .replaceAll("[^a-z0-9\\s-]", "")
                .trim()
                .replaceAll("\\s+", "-");
    }

    private String getInitials(String s) {
        StringBuilder sb = new StringBuilder();
        for (String w : s.trim().split("\\s+")) {
            if (!w.isEmpty()) sb.append(Character.toUpperCase(w.charAt(0)));
        }
        return sb.toString();
    }

    private int countWords(String s) {
        if (s == null || s.trim().isEmpty()) return 0;
        return s.trim().split("\\s+").length;
    }
}
