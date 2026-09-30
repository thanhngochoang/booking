package com.paditech.mvpbase.common.model;

import com.google.firebase.firestore.Exclude;
import com.google.gson.annotations.SerializedName;

import java.util.HashMap;
import java.util.Map;

/**
 * Created by ThanhNgocHoang on 11/22/2017.
 */

public class User {
    @Exclude
    @SerializedName("id")
    private String id;
    @SerializedName("mail_address")
    private String mail_address;
    @SerializedName("full_name")
    private String full_name;
    @SerializedName("address")
    private String address;
    @SerializedName("status")
    private String status;
    @SerializedName("phone_number")
    private String phone_number;
    @SerializedName("avatar")
    private String avatar;
    @SerializedName("rate")
    private double rate;
    @SerializedName("camera_body")
    private String camera_body;
    @SerializedName("camera_lens")
    private String camera_lens;
    @SerializedName("gear_other")
    private String gear_other;
    @SerializedName("style")
    private String style;
    @SerializedName("price")
    private long price;
    @SerializedName("google_calendar_account")
    private String google_calendar_account;
    @SerializedName("is_photographer")
    private boolean is_photographer;

    public boolean isIs_photographer() {
        return is_photographer;
    }

    public void setIs_photographer(boolean is_photographer) {
        this.is_photographer = is_photographer;
    }

    public String getId() {
        return id;
    }

    public String getMail_address() {
        return mail_address;
    }

    public String getFull_name() {
        return full_name;
    }

    public String getAddress() {
        return address;
    }

    public String getStatus() {
        return status;
    }

    public String getPhone_number() {
        return phone_number;
    }

    public String getAvatar() {
        return avatar;
    }

    public double getRate() {
        return rate;
    }

    public String getCamera_body() {
        return camera_body;
    }

    public String getCamera_lens() {
        return camera_lens;
    }

    public String getGear_other() {
        return gear_other;
    }

    public String getStyle() {
        return style;
    }

    public long getPrice() {
        return price;
    }

    public String getGoogle_calendar_account() {
        return google_calendar_account;
    }

    public void setId(String id) {
        this.id = id;
    }

    public void setMail_address(String mail_address) {
        this.mail_address = mail_address;
    }

    public void setFull_name(String full_name) {
        this.full_name = full_name;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public void setPhone_number(String phone_number) {
        this.phone_number = phone_number;
    }

    public void setAvatar(String avatar) {
        this.avatar = avatar;
    }

    public void setRate(double rate) {
        this.rate = rate;
    }

    public void setCamera_body(String camera_body) {
        this.camera_body = camera_body;
    }

    public void setCamera_lens(String camera_lens) {
        this.camera_lens = camera_lens;
    }

    public void setGear_other(String gear_other) {
        this.gear_other = gear_other;
    }

    public void setStyle(String style) {
        this.style = style;
    }

    public void setPrice(long price) {
        this.price = price;
    }

    public void setGoogle_calendar_account(String google_calendar_account) {
        this.google_calendar_account = google_calendar_account;
    }

    @Exclude
    public Map<String, Object> getMaps() {
        HashMap<String, Object> maps = new HashMap<>();
        maps.put("mail_address", mail_address);
        maps.put("full_name", full_name);
        maps.put("address", address);
        maps.put("full_name", full_name);
        maps.put("status", status);
        maps.put("phone_number", phone_number);
        maps.put("avatar", avatar);
        maps.put("rate", rate);
        maps.put("camera_body", camera_body);
        maps.put("camera_lens", camera_lens);
        maps.put("gear_other", gear_other);
        maps.put("style", style);
        maps.put("price", price);
        maps.put("google_calendar_account", google_calendar_account);
        maps.put("is_photographer", is_photographer);
        return maps;
    }
}
