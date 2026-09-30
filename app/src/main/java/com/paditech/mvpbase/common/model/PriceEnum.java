package com.paditech.mvpbase.common.model;

/**
 * Created by ThanhNgocHoang on 12/22/2017.
 */

public enum PriceEnum {
    PRICE_1(200000, 500000, "200K - 500K"),
    PRICE_2(500000, 700000, "500K - 700K"),
    PRICE_3(700000, 1000000, "700K - 1000K"),
    PRICE_4(1000000, 2000000, "1M - 2M"),
    PRICE_5(-1, -1, "trên 2M");

    private long min, max;
    private String text;

    PriceEnum(long min, long max, String text) {
        this.min = min;
        this.max = max;
        this.text = text;
    }

    public long getMin() {
        return min;
    }

    public long getMax() {
        return max;
    }

    public String getText() {
        return text;
    }
}
