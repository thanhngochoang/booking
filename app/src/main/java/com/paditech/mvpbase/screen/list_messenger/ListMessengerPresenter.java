package com.paditech.mvpbase.screen.list_messenger;

import com.paditech.mvpbase.common.model.ChatRoom;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;

import java.util.ArrayList;

import io.realm.Realm;
import io.realm.RealmResults;

/**
 * Created by ThanhNgocHoang on 12/16/2017.
 */

public class ListMessengerPresenter extends FragmentPresenter<ListMessengerContact.ViewOps> implements ListMessengerContact.PresenterViewOps {

    @Override
    public void getListMessage() {
        try {
            RealmResults<ChatRoom> realmResults = Realm.getDefaultInstance().where(ChatRoom.class).sort("create_time").findAll();
            getView().updateListRoom(new ArrayList<ChatRoom>(realmResults));
            /*FirebaseFirestore.getInstance().collection("chat_room").whereGreaterThanOrEqualTo("users", PrefUtil.getUid()).get().addOnCompleteListener(new OnCompleteListener<QuerySnapshot>() {
                @Override
                public void onComplete(@NonNull Task<QuerySnapshot> task) {
                    getView().onLoadDone();
                    if (task.isSuccessful()) {
                        ArrayList<ChatRoom> list = new ArrayList<>();
                        for (DocumentSnapshot documentSnapshot : task.getResult().getDocuments()) {
                            ChatRoom chatRoom = documentSnapshot.toObject(ChatRoom.class);
                            chatRoom.setId(documentSnapshot.getId());
                            list.add(chatRoom);
                        }
                        getView().updateListRoom(list);
                      *//*  try {
                            Realm realm = Realm.getDefaultInstance();
                            RealmResults<ChatRoom> query = realm.where(ChatRoom.class).sort("create_time").findAll();
                            getView().updateListRoom(new ArrayList<ChatRoom>(query));
                        } catch (Exception e) {
                            e.printStackTrace();
                        }*//*
                    } else getView().updateListRoom(new ArrayList<ChatRoom>());
                }
            });*/


        } catch (Exception e) {
            e.printStackTrace();
        }
    }

}
