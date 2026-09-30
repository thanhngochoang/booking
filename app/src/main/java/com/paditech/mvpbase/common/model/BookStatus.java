package com.paditech.mvpbase.common.model;

import com.paditech.mvpbase.R;

/**
 * Created by ThanhNgocHoang on 12/25/2017.
 */

public enum BookStatus {
    WAITING(0, R.string.booking_waiting, R.drawable.bg_booking_waiting, R.color.blue_transfer),
    ACCEPTED(1, R.string.booking_accepted, R.drawable.bg_booking_accepted, R.color.green_transfer),
    DENIED(2, R.string.booking_denied, R.drawable.bg_booking_denied, R.color.red_transfer),
    OPENED(3, R.string.booking_open, R.drawable.bg_booking_opening, R.color.yellow_transfer),
    CLOSED(4, R.string.booking_denied, R.drawable.bg_booking_closed, R.color.closed_transfer);

    private int status, text, background, color;

    BookStatus(int i, int t, int bg, int color) {
        this.status = i;
        this.text = t;
        this.background = bg;
        this.color = color;
    }

    public int getColor() {
        return color;
    }

    public int getBackground() {
        return background;
    }

    public int getStatus() {
        return status;
    }

    public int getText() {
        return text;
    }
}
