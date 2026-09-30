package com.paditech.mvpbase.common.model;

import com.google.firebase.database.Exclude;

import java.text.SimpleDateFormat;
import java.util.Date;

/**
 * Created by NhaPCS on 09/04/2017.
 */

public class Message {
    public String id;
    public String content;
    public long create_time;
    public String owner;
    public String image;

    @Exclude
    public String getTime() {
        if (create_time <= 0) return "";
        Date date = new Date(create_time);
        Date curr = new Date();
        if (date.getDate() == curr.getDate()) {
            SimpleDateFormat format = new SimpleDateFormat("hh:mm");
            return format.format(date);
        } else {
            if (date.getYear() == curr.getYear()) {
                SimpleDateFormat format = new SimpleDateFormat("hh:mm dd/MM");
                return format.format(date);
            } else {
                SimpleDateFormat format = new SimpleDateFormat("dd/MM/yy");
                return format.format(date);
            }
        }
    }

    public String getId() {
        return id;
    }

    public String getContent() {
        return content;
    }

    public long getCreate_time() {
        return create_time;
    }

    public String getOwner() {
        return owner;
    }

    public String getImage() {
        return image;
    }
}
