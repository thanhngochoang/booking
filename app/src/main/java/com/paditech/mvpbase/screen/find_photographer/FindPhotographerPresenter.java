package com.paditech.mvpbase.screen.find_photographer;

import androidx.annotation.NonNull;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.QuerySnapshot;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.utils.PrefUtil;

import java.util.ArrayList;

/**
 * Created by ThanhNgocHoang on 11/15/2017.
 */

public class FindPhotographerPresenter extends FragmentPresenter<FindPhotographerContact.ViewOps> implements FindPhotographerContact.PresenterViewOps {
    @Override
    public void onSearchPhotographers(double lat, double lng, int rate) {
        try {
            getView().onLoading();
            FirebaseFirestore.getInstance().collection("users").whereEqualTo("is_photographer", true).get().addOnCompleteListener(new OnCompleteListener<QuerySnapshot>() {
                @Override
                public void onComplete(@NonNull Task<QuerySnapshot> task) {
                    getView().onLoadDone();
                    if (task.isSuccessful()) {
                        ArrayList<User> photographers = new ArrayList<>();
                        if (task.getResult() != null && !task.getResult().isEmpty()) {
                            for (DocumentSnapshot documentSnapshot : task.getResult().getDocuments()) {
                                User photographer = documentSnapshot.toObject(User.class);
                                if (!documentSnapshot.getId().equals(PrefUtil.getUid()))
                                    photographers.add(photographer);
                            }
                        }
                        getView().onSearchResults(photographers);
                    } else getView().onSearchResults(new ArrayList<User>());
                }
            });
        } catch (Exception e) {
            getView().onLoadDone();
            e.printStackTrace();
        }
    }
}
