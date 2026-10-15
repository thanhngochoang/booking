package com.paditech.mvpbase.screen.profile;

import android.content.Intent;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import android.view.View;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.firebase.FirebaseHelper;
import com.paditech.mvpbase.common.firebase.GetUserInfoListener;
import com.paditech.mvpbase.common.model.Comment;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.common.utils.PrefUtil;
import com.paditech.mvpbase.common.utils.StringUtil;
import com.paditech.mvpbase.screen.album.AlbumFragment;
import com.paditech.mvpbase.screen.update_profile.UpdateProfileActivity;

import java.util.ArrayList;

import butterknife.BindView;
import butterknife.OnClick;

/**
 * Created by ThanhNgocHoang on 11/15/2017.
 */

public class ProfileFragment extends MVPFragment<ProfileContact.PresenterViewOps>
        implements ProfileContact.ViewOps {

    @BindView(R.id.recycler_view)
    RecyclerView recyclerView;

    private ProfileAdapter mProfileAdapter;
    private String mUserId;

    public static ProfileFragment newInstance() {
        ProfileFragment profileFragment = new ProfileFragment();
        return profileFragment;
    }

    public static ProfileFragment newInstance(String userId) {
        ProfileFragment profileFragment = new ProfileFragment();
        profileFragment.mUserId = userId;
        return profileFragment;
    }

    @Override
    protected int getContentView() {
        return R.layout.frag_about;
    }

    @Override
    protected void initView(View view) {
        setupRecyclerView();
    }

    @Override
    protected String getTitle() {
        return getString(R.string.about);
    }


    private void setupRecyclerView() {
        mProfileAdapter = new ProfileAdapter();
        recyclerView.setLayoutManager(new LinearLayoutManager(getActivityContext()));
        recyclerView.setAdapter(mProfileAdapter);
        if (StringUtil.isEmpty(mUserId)) {
            mUserId = PrefUtil.getUid();
            mProfileAdapter.setmUser(PrefUtil.getUser(getActivityContext()));
        } else {
            FirebaseHelper.getUserInfo(mUserId, new GetUserInfoListener() {
                @Override
                public void getUserInfo(User user) {
                    if (user != null) mProfileAdapter.setmUser(user);
                }
            });
        }
        if (PrefUtil.isLogin())
            getPresenter().getListComments(PrefUtil.getUid());
    }

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return ProfilePresenter.class;
    }


    @OnClick({R.id.btn_about, R.id.btn_album, R.id.btn_book})
    public void onViewClicked(View view) {
        switch (view.getId()) {
            case R.id.btn_about:
                Intent intent = new Intent(getActivityContext(), UpdateProfileActivity.class);
                intent.putExtra("user_id", mUserId);
                startActivity(intent);
                break;
            case R.id.btn_album:
                replaceFragment(AlbumFragment.newInstance(mUserId), true);
                break;
            case R.id.btn_book:
                break;
        }
    }

    @Override
    public void updateListComments(ArrayList<Comment> comments) {
        if (comments == null) return;
        mProfileAdapter.setmListComments(comments);
    }


    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

}
