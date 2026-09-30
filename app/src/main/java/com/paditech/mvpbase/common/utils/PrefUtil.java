package com.paditech.mvpbase.common.utils;

import android.content.Context;
import android.content.SharedPreferences;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.database.FirebaseDatabase;
import com.google.gson.Gson;
import com.paditech.mvpbase.common.model.Device;
import com.paditech.mvpbase.common.model.User;

/**
 * dienquang_android_user
 * <p>
 * Created by Paditech on 2/24/2017.
 * Copyright (c) 2017 Paditech. All rights reserved.
 */
public class PrefUtil {
    private static final String PRE_USER = "pre:user_id";
    private static final String PRE_CALENDAR_ACCOUNT = "pre:calendar:account";

    private static SharedPreferences getPreferences(Context context) {
        return context.getSharedPreferences(context.getPackageName(), Context.MODE_PRIVATE);
    }

    public static void savePreferences(Context context, String key, boolean content) {
        final SharedPreferences.Editor editor = getPreferences(context).edit();
        editor.putBoolean(key, content);
        editor.apply();
    }

    public static void savePreferences(Context context, String key, String content) {
        final SharedPreferences.Editor editor = getPreferences(context).edit();
        editor.putString(key, content);
        editor.apply();
    }

    public static void savePreferences(Context context, String key, int content) {
        final SharedPreferences.Editor editor = getPreferences(context).edit();
        editor.putInt(key, content);
        editor.apply();
    }

    public static boolean getPreferences(Context context, String key) {
        SharedPreferences preferences = getPreferences(context);
        return preferences.getBoolean(key, true);
    }

    public static String getPreferences(Context context, String key, String defVal) {
        SharedPreferences preferences = getPreferences(context);
        return preferences.getString(key, defVal);
    }

    public static int getPreferences(Context context, String key, int defVal) {
        SharedPreferences preferences = getPreferences(context);
        return preferences.getInt(key, defVal);
    }

    public static void saveCalendarAccount(Context context, String account) {
        try {
            savePreferences(context, PRE_CALENDAR_ACCOUNT, account);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static String getCalendarAccount(Context context) {
        return getPreferences(context, PRE_CALENDAR_ACCOUNT, "");
    }

    public static boolean isLogin() {
        FirebaseAuth mAuth = FirebaseAuth.getInstance();
        if (mAuth == null) return false;
        if (mAuth.getCurrentUser() != null) return true;
        return false;
    }

    public static void logout(Context context) {
        try {
            FirebaseAuth.getInstance().signOut();
            final SharedPreferences.Editor editor = getPreferences(context).edit();
            editor.clear();
            editor.apply();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static String getUid() {
        FirebaseAuth mAuth = FirebaseAuth.getInstance();
        if (mAuth == null) return "";
        if (mAuth.getCurrentUser() != null) return mAuth.getCurrentUser().getUid();
        return "";
    }


    public static void saveUser(Context context, User user) {
        try {
            savePreferences(context, PRE_USER, new Gson().toJson(user));
            Device device = new Device(context);
            FirebaseDatabase.getInstance().getReference().child("user_devices").child(user.getId()).setValue(device);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static User getUser(Context context) {
        try {
            return new Gson().fromJson(getPreferences(context, PRE_USER, ""), User.class);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    public static boolean isPhotographer(Context context) {
        User user = getUser(context);
        if (user != null) return user.isIs_photographer();
        return false;
    }


}
