package com.paditech.mvpbase.common.firebase;

import android.support.annotation.NonNull;
import android.util.Log;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.QuerySnapshot;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.model.ChatRoom;
import com.paditech.mvpbase.common.model.Message;
import com.paditech.mvpbase.common.model.User;

import java.util.ArrayList;
import java.util.Iterator;

/**
 * Created by ThanhNgocHoang on 12/19/2017.
 */

public class FirebaseHelper {
    public static void getUserInfo(String userId, final GetUserInfoListener listener) {
        try {
            FirebaseFirestore.getInstance().collection("users").document(userId).get().addOnCompleteListener(new OnCompleteListener<DocumentSnapshot>() {
                @Override
                public void onComplete(@NonNull Task<DocumentSnapshot> task) {
                    if (task.isSuccessful() && task.getResult().exists()) {
                        User user = task.getResult().toObject(User.class);
                        user.setId(task.getResult().getId());
                        listener.getUserInfo(user);
                    }
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static void getTimeAndMessageChatRoom(String roomId, final GetTimeAndMessageChatRoomListener listener) {
        try {
            FirebaseDatabase.getInstance().getReference().child("chat_room").child(roomId).child("messages").addListenerForSingleValueEvent(new ValueEventListener() {
                @Override
                public void onDataChange(DataSnapshot dataSnapshot) {
                    if (dataSnapshot.getValue() != null) {
                        Iterator<DataSnapshot> snapshots = dataSnapshot.getChildren().iterator();
                        DataSnapshot chatSnap = null;
                        while (snapshots.hasNext()) {
                            chatSnap = snapshots.next();
                        }
                        if (chatSnap != null) {
                            Message message = chatSnap.getValue(Message.class);
                            if (message != null) {
                                listener.onGetData(message.getContent(), message.create_time);
                            }
                        }
                    }
                }

                @Override
                public void onCancelled(DatabaseError databaseError) {

                }
            });
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static void getListAttend(Booking booking, final GetListAttendListener listener) {
        try {
            FirebaseFirestore.getInstance().collection("booking").document(booking.getId()).collection("photographers_attended").get().addOnCompleteListener(new OnCompleteListener<QuerySnapshot>() {
                @Override
                public void onComplete(@NonNull Task<QuerySnapshot> task) {
                    if (task.isSuccessful() && task.getResult() != null) {
                        ArrayList<User> users = new ArrayList<>();
                        for (DocumentSnapshot documentSnapshot : task.getResult().getDocuments()) {
                            User user = documentSnapshot.toObject(User.class);
                            users.add(user);
                        }
                        listener.getListAttened(users);
                    } else listener.getListAttened(null);
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public interface GetListAttendListener {
        void getListAttened(ArrayList<User> users);

    }
}
