package com.paditech.mvpbase.common.model;

import com.google.firebase.database.Exclude;
import com.paditech.mvpbase.common.utils.PrefUtil;
import com.paditech.mvpbase.common.utils.StringUtil;

import java.util.ArrayList;
import java.util.Map;

import io.realm.RealmObject;
import io.realm.annotations.Ignore;
import io.realm.annotations.PrimaryKey;

/**
 * Created by Administrator on 15/02/2017.
 */

public class ChatRoom extends RealmObject{
    @PrimaryKey
    private String id;
    private String users;
    private long create_time;
    private boolean is_read;

    public String getId() {
        return id;
    }

    public long getCreate_time() {
        return create_time;
    }

    public boolean isIs_read() {
        return is_read;
    }

    public ChatRoom() {
    }

    public ChatRoom(String id, String users, long create_time) {
        this.id = id;
        this.users = users;
        this.create_time = create_time;
    }


    public void setId(String id) {
        this.id = id;
    }

    public String getUsers() {
        return users;
    }

    public void setUsers(String users) {
        this.users = users;
    }

    public void setCreate_time(long create_time) {
        this.create_time = create_time;
    }

    public void setIs_read(boolean is_read) {
        this.is_read = is_read;
    }

    //extra values
    @Ignore
    @Exclude
    private long lastTime;
    @Ignore
    @Exclude
    private String lastMessage;
    @Ignore
    @Exclude
    private String room_name;
    @Exclude
    @Ignore
    private String room_avatar;
    @Ignore
    @Exclude
    private ArrayList<String> list_users;

    @Exclude
    public ArrayList<String> getList_users() {
        if (list_users != null)
            return list_users;
        else {
            if (users.contains(";")) {
                String[] list = users.split(";");
                list_users = new ArrayList<>();
                for (String u : list) {
                    if (!StringUtil.isEmpty(u)) list_users.add(u);
                }
                return list_users;
            }
        }
        return null;
    }

    @Exclude
    public void setList_users(ArrayList<String> list_users) {
        this.list_users = list_users;
    }

    @Exclude
    public String getRoom_name() {
        return room_name;
    }

    @Exclude
    public void setRoom_name(String room_name) {
        this.room_name = room_name;
    }

    @Exclude
    public String getRoom_avatar() {
        return room_avatar;
    }

    @Exclude
    public void setRoom_avatar(String room_avatar) {
        this.room_avatar = room_avatar;
    }

    @Exclude
    public long getLastTime() {
        return lastTime;
    }

    @Exclude
    public void setLastTime(long lastTime) {
        this.lastTime = lastTime;
    }

    @Exclude
    public String getLastMessage() {
        return lastMessage;
    }

    @Exclude
    public void setLastMessage(String lastMessage) {
        this.lastMessage = lastMessage;
    }

    @Exclude
    public String getTargetId() {
        try {
            ArrayList<String> users = getList_users();
            if (users != null && users.size() == 2) {
                if (PrefUtil.getUid().equals(users.get(0))) return users.get(1);
                else return users.get(0);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        return null;
    }
}
