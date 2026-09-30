package com.paditech.mvpbase.common.utils;

import java.text.SimpleDateFormat;

/**
 * Created by ThanhNgocHoang on 12/1/2017.
 */

public class Constant {
    public static final int MAX_MESSAGE = 100;

    public static final int FILE_IMAGE_MAX_SIZE = 230;
    public static final String IMAGE_PATH = "CongDongNhiepAnh";
    public static final String IMAGE_FILE_NAME = "photo_%s";
    public static final SimpleDateFormat SIMPLE_DATE_FORMAT = new SimpleDateFormat("yyyyMMdd_HHmmss");

    public static final SimpleDateFormat FIND_TIME_FORMAT = new SimpleDateFormat("HH'h'mm");
    public static final SimpleDateFormat FIND_DATE_FORMAT = new SimpleDateFormat("dd-MM-yyyy");
    public static final SimpleDateFormat BOOK_DATE_TIME_FORMAT = new SimpleDateFormat("HH:mm dd-MM-yyyy");
    public static final SimpleDateFormat BOOK_TIME_FORMAT = new SimpleDateFormat("HH'h'mm");
    public static final SimpleDateFormat BOOK_MONTH_FORMAT= new SimpleDateFormat("'Tháng' MM, yyyy");
}
