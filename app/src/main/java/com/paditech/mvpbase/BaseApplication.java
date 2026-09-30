package com.paditech.mvpbase;

import android.content.Context;
import android.support.annotation.NonNull;
import android.support.multidex.MultiDex;
import android.support.multidex.MultiDexApplication;
import android.support.v4.content.ContextCompat;

import com.alamkanak.weekview.WeekViewEvent;
import com.facebook.FacebookSdk;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.FirebaseApp;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.EventListener;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.FirebaseFirestoreException;
import com.google.firebase.firestore.ListenerRegistration;
import com.google.firebase.firestore.QuerySnapshot;
import com.paditech.mvpbase.common.event.OnUpdateCalendarEvent;
import com.paditech.mvpbase.common.event.OnUpdateMessagesEvent;
import com.paditech.mvpbase.common.firebase.FirebaseHelper;
import com.paditech.mvpbase.common.firebase.GetUserInfoListener;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.model.ChatRoom;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.utils.PrefUtil;

import org.greenrobot.eventbus.EventBus;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;

import io.realm.Realm;
import io.realm.RealmConfiguration;

/**
 * Created by ThanhNgocHoang on 6/27/2017.
 */

public class BaseApplication extends MultiDexApplication {

    private ListenerRegistration mListenerRegistration, mListenerRegistrationCalendar, mListenerRegistrationCalendar2;

    @Override
    protected void attachBaseContext(Context context) {
        super.attachBaseContext(context);
        MultiDex.install(this);
    }

    @Override
    public void onCreate() {
        super.onCreate();
        Realm.init(getApplicationContext());
        RealmConfiguration config = new RealmConfiguration.Builder().name("timnhay.realm").build();
        Realm.setDefaultConfiguration(config);

        FacebookSdk.setApplicationId("546233675712070");
        FacebookSdk.sdkInitialize(getApplicationContext());
        FirebaseApp.initializeApp(this);
        FirebaseDatabase.getInstance().setPersistenceEnabled(true);
        FirebaseAuth.getInstance().addAuthStateListener(new FirebaseAuth.AuthStateListener() {
            @Override
            public void onAuthStateChanged(@NonNull FirebaseAuth firebaseAuth) {
                if (firebaseAuth.getCurrentUser() != null) {
                    triggerNewMessages();
                    triggerCalendar();
                } else {
                    if (mListenerRegistration != null) mListenerRegistration.remove();
                    if (mListenerRegistrationCalendar != null)
                        mListenerRegistrationCalendar.remove();
                    if (mListenerRegistrationCalendar2 != null)
                        mListenerRegistrationCalendar2.remove();
                }
            }
        });
    }

    private void triggerNewMessages() {
        mListenerRegistration = FirebaseFirestore.getInstance().collection("chat_room").whereGreaterThanOrEqualTo("users", PrefUtil.getUid())
                .addSnapshotListener(new EventListener<QuerySnapshot>() {
                    @Override
                    public void onEvent(QuerySnapshot documentSnapshots, FirebaseFirestoreException e) {
                        if (e == null && documentSnapshots != null) {
                            ArrayList<ChatRoom> list = new ArrayList<>();
                            for (DocumentSnapshot document : documentSnapshots) {
                                ChatRoom chatRoom = document.toObject(ChatRoom.class);
                                chatRoom.setId(document.getId());
                                list.add(chatRoom);
                            }

                            Realm realm = Realm.getDefaultInstance();
                            realm.beginTransaction();
                            realm.insertOrUpdate(list);
                            realm.commitTransaction();
                            realm.close();
                            EventBus.getDefault().post(new OnUpdateMessagesEvent());
                        }
                    }
                });
    }


    private void triggerCalendar() {
        mListenerRegistrationCalendar = FirebaseFirestore.getInstance().collection("booking").whereEqualTo("photographer_id", PrefUtil.getUid()).addSnapshotListener(new EventListener<QuerySnapshot>() {
            @Override
            public void onEvent(QuerySnapshot documentSnapshots, FirebaseFirestoreException e) {
                if (e == null && documentSnapshots != null) {
                    final List<Booking> bookings = new ArrayList<>();
                    for (DocumentSnapshot document : documentSnapshots) {
                        final Booking booking = document.toObject(Booking.class);
                        booking.setId(document.getId());
                        bookings.add(booking);
                    }
                    Realm realm = Realm.getDefaultInstance();
                    realm.beginTransaction();
                    realm.insertOrUpdate(bookings);
                    realm.commitTransaction();
                    realm.close();
                    EventBus.getDefault().post(new OnUpdateCalendarEvent());
                }
            }
        });

        mListenerRegistrationCalendar2 = FirebaseFirestore.getInstance().collection("booking").whereEqualTo("user_id", PrefUtil.getUid()).addSnapshotListener(new EventListener<QuerySnapshot>() {
            @Override
            public void onEvent(QuerySnapshot documentSnapshots, FirebaseFirestoreException e) {
                if (e == null && documentSnapshots != null) {
                    final List<Booking> bookings = new ArrayList<>();
                    for (DocumentSnapshot document : documentSnapshots) {
                        final Booking booking = document.toObject(Booking.class);
                        booking.setId(document.getId());
                        bookings.add(booking);
                    }
                    Realm realm = Realm.getDefaultInstance();
                    realm.beginTransaction();
                    realm.insertOrUpdate(bookings);
                    realm.commitTransaction();
                    realm.close();
                    EventBus.getDefault().post(new OnUpdateCalendarEvent());
                }
            }
        });
    }
}
