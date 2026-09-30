package com.paditech.mvpbase.common.model;

import com.google.gson.annotations.SerializedName;

/**
 * Created by ThanhNgocHoang on 12/18/2017.
 */

public class Rate {
    @SerializedName("rate_total")
    private double rate_total;
    @SerializedName("rate_count")
    private long rate_count;
    @SerializedName("comment")
    private String comment;

    public String getComment() {
        return comment;
    }

    public void setComment(String comment) {
        this.comment = comment;
    }

    public double getRate_total() {
        return rate_total;
    }

    public void setRate_total(double rate_total) {
        this.rate_total = rate_total;
    }

    public long getRate_count() {
        return rate_count;
    }

    public void setRate_count(long rate_count) {
        this.rate_count = rate_count;
    }
}
