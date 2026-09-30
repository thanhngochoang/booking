package com.paditech.mvpbase.common.utils;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.provider.Settings;
import android.text.Html;
import android.text.Spannable;
import android.text.TextPaint;
import android.text.style.URLSpan;
import android.text.style.UnderlineSpan;
import android.util.Base64;
import android.util.Log;

import com.paditech.mvpbase.R;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.text.DecimalFormat;
import java.text.NumberFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * dienquang_android_thodien
 * <p>
 * Created by Paditech on 2/16/2017.
 * Copyright (c) 2017 Paditech. All rights reserved.
 */

public class StringUtil {

    private static final SimpleDateFormat mSimpleDateFormat = new SimpleDateFormat("yyyy-MM-dd");
    private static final SimpleDateFormat mDateFormat = new SimpleDateFormat("dd-MM-yyyy");

    private static final String EMAIL_PATTERN = "^[_A-Za-z0-9-\\+]+(\\.[_A-Za-z0-9-]+)*@"
            + "[A-Za-z0-9-]+(\\.[A-Za-z0-9]+)*(\\.[A-Za-z]{2,})$";

    private static final String NUMBER_PATTERN = "[0-9]+";

    private static final String DATE_FORMAT = "yyyy-MM-dd";

    public static boolean isEmpty(String string) {
        return string == null || string.length() == 0;
    }

    public static boolean isNumber(String string) {
        Pattern pattern = Pattern.compile(NUMBER_PATTERN, Pattern.CASE_INSENSITIVE);
        Matcher matcher = pattern.matcher(string);
        return matcher.matches();
    }

    public static boolean isEmailValid(String email) {
        Pattern pattern = Pattern.compile(EMAIL_PATTERN, Pattern.CASE_INSENSITIVE);
        Matcher matcher = pattern.matcher(email);
        return matcher.matches();
    }

    public static String getPriceVND(long price) {
        if (price < 0) price = 0;
        return NumberFormat.getNumberInstance(Locale.GERMAN).format(price);
    }

    public static String getPriceVNDCurrency(long price) {
        if (price < 0) price = 0;
        return NumberFormat.getNumberInstance(Locale.GERMAN).format(price) + " VNĐ";
    }

    public static Spannable removeUnderline(String str) {
        Spannable s = (Spannable) Html.fromHtml(str);
        for (URLSpan u : s.getSpans(0, s.length(), URLSpan.class)) {
            s.setSpan(new UnderlineSpan() {
                public void updateDrawState(TextPaint tp) {
                    tp.setUnderlineText(false);
                }
            }, s.getSpanStart(u), s.getSpanEnd(u), 0);
        }
        return s;
    }

    public static String getUUID(Context context) {
        return Settings.Secure.getString(context.getContentResolver(), Settings.Secure.ANDROID_ID);
    }

    public static void getKeyHash(Context context) {
        try {
            PackageInfo info = context.getPackageManager().getPackageInfo(
                    context.getPackageName(),
                    PackageManager.GET_SIGNATURES);
            for (Signature signature : info.signatures) {
                MessageDigest md = MessageDigest.getInstance("SHA");
                md.update(signature.toByteArray());
                Log.d("KeyHash:", Base64.encodeToString(md.digest(), Base64.DEFAULT));
            }
        } catch (PackageManager.NameNotFoundException e) {

        } catch (NoSuchAlgorithmException e) {

        }
    }

    private final static long seconds = 1000;

    public static String getTimeCreated(Context context, long created) {
        long diff = Math.abs(System.currentTimeMillis() - created);

        if (diff < seconds * 3) {
            return context.getString(R.string.just_now);
        } else if (diff < seconds * 60) {
            int d = (int) (diff / seconds);
            return String.format(context.getString(R.string.some_seconds_ago), String.valueOf(d));
        } else if (diff < seconds * 60 * 2) {
            return context.getString(R.string.one_minute_ago);
        } else if (diff < seconds * 60 * 60) {
            int d = (int) (diff / (seconds * 60));
            return String.format(context.getString(R.string.some_minute_ago), String.valueOf(d));
        } else if (diff < seconds * 60 * 60 * 2) {
            return context.getString(R.string.one_hour_ago);
        } else if (diff < seconds * 60 * 60 * 12) {
            int d = (int) (diff / (seconds * 60 * 60));
            return String.format(context.getString(R.string.some_hour_ago), String.valueOf(d));
        } else if (diff > seconds * 60 * 60 * 24 * 365) {
            Date date = new Date(created);
            SimpleDateFormat format = new SimpleDateFormat("dd-MM-yyyy");
            return format.format(date);
        }

        Date date = new Date(created);
        Date curr = new Date(System.currentTimeMillis());
        if (curr.getYear() > date.getYear()) {
            SimpleDateFormat format = new SimpleDateFormat("dd-MM-yyyy");
            return format.format(date);
        } else {
            SimpleDateFormat format = new SimpleDateFormat("dd-MM-yyyy");
            return format.format(date);
        }
    }
}
