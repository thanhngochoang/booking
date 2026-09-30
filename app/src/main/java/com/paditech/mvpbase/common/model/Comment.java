package com.paditech.mvpbase.common.model;

import com.google.firebase.firestore.Exclude;

/**
 * Created by ThanhNgocHoang on 12/2/2017.
 */

public class Comment {
    @Exclude
    private String id;
    private String user_id;
    private String user_name;
    private double rate;
    private String content;
    private long create_time;

    public String getId() {
        return id;
    }

    public String getUser_id() {
        return user_id;
    }

    public String getUser_name() {
        return user_name;
    }

    public double getRate() {
        return rate;
    }

    public String getContent() {
        return content;
    }

    public long getCreate_time() {
        return create_time;
    }
}
