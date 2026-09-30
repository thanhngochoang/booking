package com.paditech.mvpbase.screen.messenger;

import android.net.Uri;
import android.os.AsyncTask;
import android.support.annotation.NonNull;
import android.util.Log;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.database.ChildEventListener;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.QuerySnapshot;
import com.google.firebase.storage.FirebaseStorage;
import com.google.firebase.storage.StorageReference;
import com.google.firebase.storage.UploadTask;
import com.paditech.mvpbase.common.model.ChatRoom;
import com.paditech.mvpbase.common.model.Message;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.utils.CommonUtil;
import com.paditech.mvpbase.common.utils.Constant;
import com.paditech.mvpbase.common.utils.PrefUtil;
import com.paditech.mvpbase.common.utils.StringUtil;

import java.io.File;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

/**
 * Created by ThanhNgocHoang on 11/15/2017.
 */

public class MessengerPresenter extends FragmentPresenter<MessengerContact.ViewOps> implements MessengerContact.PresenterViewOps {
    private ChatRoom mChatRoom;
    private String mTargetId;

    @Override
    public void sendMessage(final String content) {
        if (!CommonUtil.hasConnected(getView().getActivityContext()))
            return;
        if (mChatRoom != null) {
            doSendMessage(content);
        }
    }

    @Override
    public void setChatRoom(ChatRoom chatRoom) {
        this.mChatRoom = chatRoom;
        this.mTargetId = chatRoom.getTargetId();
    }

    @Override
    public void setPhotographer(String targetId) {
        this.mTargetId = targetId;
    }


    private void createRoom() {
        final String key = FirebaseFirestore.getInstance().collection("chat_room").document().getId();
        mChatRoom = new ChatRoom(key, PrefUtil.getUid() + ";" + mTargetId, new Date().getTime());
        FirebaseFirestore.getInstance().collection("chat_room").document(key).set(mChatRoom).addOnCompleteListener(new OnCompleteListener<Void>() {
            @Override
            public void onComplete(@NonNull Task<Void> task) {
                getMessage();
                FirebaseDatabase.getInstance().getReference().child("chat_room").child(key).setValue(mChatRoom);
            }
        });
    }

    public void findRoom(final String targetId, final FindRoomListener listener) {
        FirebaseFirestore.getInstance().collection("chat_room").whereGreaterThanOrEqualTo("users", PrefUtil.getUid()).whereGreaterThanOrEqualTo("users", targetId).get().addOnCompleteListener(new OnCompleteListener<QuerySnapshot>() {
            @Override
            public void onComplete(@NonNull Task<QuerySnapshot> task) {
                if (task.isSuccessful()) {
                    mChatRoom = checkExistRoom(task.getResult().getDocuments(), targetId);
                    if (mChatRoom != null) listener.onResult(mChatRoom);
                    else listener.onResult(null);
                } else listener.onResult(null);
            }
        });

    }

    private ChatRoom checkExistRoom(List<DocumentSnapshot> documentSnapshots, String targetId) {
        for (DocumentSnapshot snapshot : documentSnapshots) {
            try {
                ChatRoom chatRoom = snapshot.toObject(ChatRoom.class);
                chatRoom.setId(snapshot.getId());
                if (chatRoom.getUsers().contains(";")) {
                    String[] list = chatRoom.getUsers().split(";");
                    ArrayList<String> results = new ArrayList<>();
                    for (String u : list) {
                        if (!StringUtil.isEmpty(u)) results.add(u);
                    }
                    if (results.contains(PrefUtil.getUid()) && results.contains(targetId)) {
                        return chatRoom;
                    }
                }


            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        return null;
    }


    public interface FindRoomListener {
        void onResult(ChatRoom chatRoom);
    }

    public interface CreateRoomListener {
        void onCreated(ChatRoom room);
    }

    private void doSendMessage(String mess) {
        if (mChatRoom == null) return;
        final String key = FirebaseDatabase.getInstance().getReference().child("chat_room").child(mChatRoom.getId()).child("messages").push().getKey();
        final Message message = new Message();
        message.owner = PrefUtil.getUid();
        if (!StringUtil.isEmpty(mess)) {
            message.create_time = new Date().getTime();
            message.content = mess;
            FirebaseDatabase.getInstance().getReference().child("chat_room").child(mChatRoom.getId()).child("messages").child(key).setValue(message);
        }
        Log.d("message", key);
    }

    private void doSendMessageHasFile(File image) {
        if (mChatRoom == null) return;
        final String key = FirebaseDatabase.getInstance().getReference().child("chat_room").child(mChatRoom.getId()).child("messages").push().getKey();
        final Message message = new Message();
        message.owner = PrefUtil.getUid();
        if (image != null && image.isFile()) {
            Uri file = Uri.fromFile(image);
            StorageReference photoStorage = FirebaseStorage.getInstance().getReference().child("image").child(file.getLastPathSegment());
            photoStorage.putFile(file).addOnCompleteListener(new OnCompleteListener<UploadTask.TaskSnapshot>() {
                @Override
                public void onComplete(@NonNull Task<UploadTask.TaskSnapshot> task) {
                    if (task.isSuccessful()) {
                        @SuppressWarnings("VisibleForTests")
                        String imageUrl = task.getResult().getDownloadUrl().toString();
                        if (!StringUtil.isEmpty(imageUrl)) {
                            message.create_time = new Date().getTime();
                            message.image = imageUrl;
                            FirebaseDatabase.getInstance().getReference().child("chat_room").child(mChatRoom.getId()).child("messages").child(key).setValue(message);
                        }
                    }
                }
            });
        }

        Log.d("message", key);
    }

    @Override
    public void getMessage() {
        if (mTargetId == null) return;
        if (mChatRoom == null) {
            findRoom(mTargetId, new FindRoomListener() {
                @Override
                public void onResult(final ChatRoom chatRoom) {
                    if (chatRoom == null) {
                        createRoom();
                    } else {
                        mChatRoom = chatRoom;
                        getMessage();
                    }
                }
            });
        } else {
            FirebaseDatabase.getInstance().getReference().child("chat_room")
                    .child(mChatRoom.getId()).child("messages").limitToLast(Constant.MAX_MESSAGE)
                    .addChildEventListener(new ChildEventListener() {
                        @Override
                        public void onChildAdded(DataSnapshot dataSnapshot, String s) {
                            Message message = dataSnapshot.getValue(Message.class);
                            if (message != null) {
                                getView().addMessage(message);
                            }
                        }

                        @Override
                        public void onChildChanged(DataSnapshot dataSnapshot, String s) {

                        }

                        @Override
                        public void onChildRemoved(DataSnapshot dataSnapshot) {

                        }

                        @Override
                        public void onChildMoved(DataSnapshot dataSnapshot, String s) {

                        }

                        @Override
                        public void onCancelled(DatabaseError databaseError) {

                        }
                    });
        }
    }

    @Override
    public void setRead() {
        if (mChatRoom != null) {
            FirebaseFirestore.getInstance().collection("chat_room").document(mChatRoom.getId()).update("is_read", true);
        }
    }

}
