package com.paditech.mvpbase.screen.messenger;

import com.paditech.mvpbase.common.model.ChatRoom;
import com.paditech.mvpbase.common.model.Message;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenterViewOps;
import com.paditech.mvpbase.common.mvp.fragment.FragmentViewOps;

/**
 * Created by ThanhNgocHoang on 11/15/2017.
 */

public interface MessengerContact {
    interface ViewOps extends FragmentViewOps {
        void addMessage(Message message);

    }

    interface PresenterViewOps extends FragmentPresenterViewOps {
        void sendMessage(String content);
        void setChatRoom(ChatRoom chatRoom);
        void setPhotographer(String targetId);
        void getMessage();
        void setRead();
    }
}
