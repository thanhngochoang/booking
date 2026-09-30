package com.paditech.mvpbase.common.firebase;

/**
 * Created by ThanhNgocHoang on 12/19/2017.
 */

public interface GetTimeAndMessageChatRoomListener {
    void onGetData(String lastMessage, long last_time);
}
