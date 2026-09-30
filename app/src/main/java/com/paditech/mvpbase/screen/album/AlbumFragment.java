package com.paditech.mvpbase.screen.album;

import android.os.Bundle;
import android.support.annotation.Nullable;
import android.support.v4.widget.SwipeRefreshLayout;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.View;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.event.UploadAlbumSuccess;
import com.paditech.mvpbase.common.model.Album;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.common.utils.PrefUtil;
import com.paditech.mvpbase.common.utils.StringUtil;
import com.paditech.mvpbase.screen.create_album.AddImageAdapter;
import com.paditech.mvpbase.screen.create_album.CreateAlbumFragment;
import com.paditech.mvpbase.screen.home.GalleryAdapter;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.util.ArrayList;

import butterknife.BindView;
import butterknife.OnClick;

/**
 * Created by ThanhNgocHoang on 12/1/2017.
 */

public class AlbumFragment extends MVPFragment<AlbumContact.PresenterViewOps> implements AlbumContact.ViewOps, SwipeRefreshLayout.OnRefreshListener {
    @BindView(R.id.recycler_view)
    RecyclerView recyclerView;
    @BindView(R.id.swipe_refresh_layout)
    SwipeRefreshLayout swipeRefreshLayout;
    @BindView(R.id.btn_create)
    View btnCreate;

    private GalleryAdapter mGalleryAdapter;
    private String mUserId;

    public static AlbumFragment newInstance(String userId) {
        AlbumFragment albumFragment = new AlbumFragment();
        albumFragment.mUserId = userId;
        return albumFragment;
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EventBus.getDefault().register(this);
    }

    @Override
    public void onDestroy() {
        EventBus.getDefault().unregister(this);
        super.onDestroy();
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onSuccessEvent(UploadAlbumSuccess uploadAlbumSuccess) {
        showToast(getString(R.string.mess_upload_album_success));
        getPresenter().getMyAlbums(mUserId);
    }

    @Override
    protected int getContentView() {
        return R.layout.frag_album;
    }

    @Override
    protected void initView(View view) {
        if (StringUtil.isEmpty(mUserId)) mUserId = PrefUtil.getUid();
        if (!mUserId.equals(PrefUtil.getUid())) btnCreate.setVisibility(View.GONE);
        swipeRefreshLayout.setColorSchemeResources(R.color.colorDark);
        swipeRefreshLayout.setOnRefreshListener(this);
        mGalleryAdapter = new GalleryAdapter();
        recyclerView.setLayoutManager(new LinearLayoutManager(getActivityContext()));
        recyclerView.setAdapter(mGalleryAdapter);
        getPresenter().getMyAlbums(mUserId);
    }

    @Override
    protected String getTitle() {
        return getString(R.string.album);
    }

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return AlbumPresenter.class;
    }

    @OnClick(R.id.btn_create)
    public void onViewClicked() {
        replaceFragment(new CreateAlbumFragment(), true);
    }

    @Override
    public void onUpdateAlbums(ArrayList<Album> albums) {
        mGalleryAdapter.setmListAlbums(albums);
    }

    @Override
    public void onLoadDone() {
        super.onLoadDone();
        swipeRefreshLayout.setRefreshing(false);
    }

    @Override
    public void onLoading() {
        super.onLoading();
        swipeRefreshLayout.setRefreshing(true);
    }

    @Override
    public void onRefresh() {
        getPresenter().getMyAlbums(mUserId);
    }
}
