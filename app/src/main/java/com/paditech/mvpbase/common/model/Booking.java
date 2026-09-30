package com.paditech.mvpbase.common.model;

import com.google.firebase.database.Exclude;
import com.google.firebase.firestore.FieldValue;

import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

import io.realm.RealmObject;
import io.realm.annotations.Ignore;
import io.realm.annotations.PrimaryKey;

/**
 * Created by ThanhNgocHoang on 12/22/2017.
 */

public class Booking extends RealmObject {
    @PrimaryKey
    private String id;
    private String photographer_id;
    private String user_id;
    private Date start_time;
    private Date end_time;
    private Date create_time;
    private double latitude;
    private double longitude;
    private String address_name;
    private long price;
    private int status;
    private int rating_star;
    private boolean is_photographer_project;
    @Ignore
    private ArrayList<User> photographers_attended;

    public Booking() {
    }

    public Booking(String photographer_id, String user_id, Date start_time, Date end_time,
                   double latitude, double longitude, String address_name, long price) {
        this.photographer_id = photographer_id;
        this.user_id = user_id;
        this.start_time = start_time;
        this.end_time = end_time;
        this.latitude = latitude;
        this.longitude = longitude;
        this.address_name = address_name;
        this.price = price;
        this.status = BookStatus.WAITING.getStatus();
    }

    public ArrayList<User> getPhotographers_attended() {
        return photographers_attended;
    }

    public void setPhotographers_attended(ArrayList<User> photographers_attended) {
        this.photographers_attended = photographers_attended;
    }

    public boolean isIs_photographer_project() {
        return is_photographer_project;
    }

    public void setIs_photographer_project(boolean is_photographer_project) {
        this.is_photographer_project = is_photographer_project;
    }

    public void setStatus(int status) {
        this.status = status;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getId() {
        return id;
    }

    public String getPhotographer_id() {
        return photographer_id;
    }

    public String getUser_id() {
        return user_id;
    }

    public Date getStart_time() {
        return start_time;
    }

    public Date getEnd_time() {
        return end_time;
    }

    public Date getCreate_time() {
        return create_time;
    }

    public double getLatitude() {
        return latitude;
    }

    public double getLongitude() {
        return longitude;
    }

    public String getAddress_name() {
        return address_name;
    }

    public long getPrice() {
        return price;
    }

    public int getRating_star() {
        return rating_star;
    }

    @Exclude
    public Map<String, Object> getMaps() {
        Map<String, Object> map = new HashMap<>();
        map.put("photographer_id", photographer_id);
        map.put("user_id", user_id);
        map.put("start_time", start_time);
        map.put("end_time", end_time);
        map.put("create_time", FieldValue.serverTimestamp());
        map.put("latitude", latitude);
        map.put("longitude", longitude);
        map.put("address_name", address_name);
        map.put("price", price);
        map.put("status", status);
        return map;
    }

    @Exclude
    public BookStatus getStatus() {
        switch (status) {
            case 0:
                return BookStatus.WAITING;
            case 1:
                return BookStatus.ACCEPTED;
            case 2:
                return BookStatus.DENIED;
            case 3:
                return BookStatus.OPENED;
            case 4:
                return BookStatus.CLOSED;
            default:
                return BookStatus.WAITING;
        }
    }

    @Ignore
    @Exclude
    private String photographer_name;
    @Ignore
    @Exclude
    private User user;
    @Ignore
    @Exclude
    private boolean hasAttends;
    @Exclude
    public boolean isHasAttends() {
        return hasAttends;
    }
    @Exclude
    public void setHasAttends(boolean hasAttends) {
        this.hasAttends = hasAttends;
    }

    @Exclude
    public User getUser() {
        return user;
    }

    @Exclude
    public void setUser(User user) {
        this.user = user;
    }

    @Exclude
    public String getPhotographer_name() {
        return photographer_name;
    }

    @Exclude
    public void setPhotographer_name(String photographer_name) {
        this.photographer_name = photographer_name;
    }
}
