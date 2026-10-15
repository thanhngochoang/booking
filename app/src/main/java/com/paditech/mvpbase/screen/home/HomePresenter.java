package com.paditech.mvpbase.screen.home;

import androidx.annotation.NonNull;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.QuerySnapshot;
import com.paditech.mvpbase.common.model.Album;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.utils.PrefUtil;

import java.util.ArrayList;

/**
 * Created by ThanhNgocHoang on 11/4/2017.
 */

public class HomePresenter extends FragmentPresenter<HomeContact.ViewOps> implements HomeContact.PresenterViewOps {
    @Override
    public void getListData() {
        //call server
        try {
            getView().onLoading();
            FirebaseFirestore.getInstance().collection("albums").get().addOnCompleteListener(new OnCompleteListener<QuerySnapshot>() {
                @Override
                public void onComplete(@NonNull Task<QuerySnapshot> task) {
                    getView().onLoadDone();
                    if (task.getResult() != null) {
                        ArrayList<Album> albums = new ArrayList<>();
                        for (DocumentSnapshot documentSnapshot : task.getResult().getDocuments()) {
                            Album album = documentSnapshot.toObject(Album.class);
                            albums.add(album);
                        }
                        getView().setList(albums);
                    }
                }
            });
        } catch (Exception e) {
            getView().onLoadDone();
            e.printStackTrace();
        }
    }
}
