package com.paditech.mvpbase.screen.list_messenger;

import com.paditech.mvpbase.common.model.ChatRoom;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenterViewOps;
import com.paditech.mvpbase.common.mvp.fragment.FragmentViewOps;

import java.util.ArrayList;

/**
 * Created by ThanhNgocHoang on 12/16/2017.
 */

public interface ListMessengerContact {
    interface ViewOps extends FragmentViewOps {
        void updateListRoom(ArrayList<ChatRoom> chatRooms);
    }

    interface PresenterViewOps extends FragmentPresenterViewOps {
        void getListMessage();
    }
}
