package com.paditech.mvpbase.screen.album;

import android.support.annotation.NonNull;

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
 * Created by ThanhNgocHoang on 12/1/2017.
 */

public class AlbumPresenter extends FragmentPresenter<AlbumContact.ViewOps> implements AlbumContact.PresenterViewOps {
    @Override
    public void getMyAlbums(String id) {
        try {
            getView().onLoading();
            FirebaseFirestore.getInstance().collection("albums").whereEqualTo("photographer_id", id).get().addOnCompleteListener(new OnCompleteListener<QuerySnapshot>() {
                @Override
                public void onComplete(@NonNull Task<QuerySnapshot> task) {
                    if (getView() != null) {
                        getView().onLoadDone();
                        if (task.getResult() != null) {
                            ArrayList<Album> albums = new ArrayList<>();
                            for (DocumentSnapshot documentSnapshot : task.getResult().getDocuments()) {
                                Album album = documentSnapshot.toObject(Album.class);
                                albums.add(album);
                            }
                            getView().onUpdateAlbums(albums);
                        }
                    }
                }
            });
        } catch (Exception e) {
            getView().onLoadDone();
            e.printStackTrace();
        }
    }
}
