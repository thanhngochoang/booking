package com.paditech.mvpbase.common.model;

import java.util.ArrayList;

/**
 * Created by ThanhNgocHoang on 12/7/2017.
 */

public class Album {
    private String photographer_id;
    private String photographer_name;
    private String photographer_image;
    private String album_name;
    private String album_desc;
    private double album_lat;
    private double album_long;
    private long create_time;
    private ArrayList<String> album_files;
    private String album_address;

    public Album() {
    }


    public Album(String album_name, String album_desc, double album_lat, double album_long,
                 ArrayList<String> album_files, String album_address) {
        this.album_name = album_name;
        this.album_desc = album_desc;
        this.album_lat = album_lat;
        this.album_long = album_long;
        this.album_files = album_files;
        this.album_address = album_address;
    }

    public String getPhotographer_id() {
        return photographer_id;
    }

    public String getPhotographer_name() {
        return photographer_name;
    }

    public String getPhotographer_image() {
        return photographer_image;
    }

    public String getAlbum_name() {
        return album_name;
    }

    public String getAlbum_desc() {
        return album_desc;
    }

    public double getAlbum_lat() {
        return album_lat;
    }

    public double getAlbum_long() {
        return album_long;
    }

    public long getCreate_time() {
        return create_time;
    }

    public ArrayList<String> getAlbum_files() {
        return album_files;
    }

    public String getAlbum_address() {
        return album_address;
    }
}
