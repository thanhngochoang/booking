package com.paditech.mvpbase.screen.home;

import android.content.Intent;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import android.view.View;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.model.Album;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.screen.profile.ProfileFragment;
import com.paditech.mvpbase.screen.view_image.ViewImageActivity;

import java.util.ArrayList;

import butterknife.BindView;

/**
 * Created by ThanhNgocHoang on 11/4/2017.
 */

public class HomeFragment extends MVPFragment<HomeContact.PresenterViewOps>
        implements HomeContact.ViewOps, ImageAdapter.OnViewImageListener, SwipeRefreshLayout.OnRefreshListener {

    @BindView(R.id.recycler_view)
    RecyclerView recyclerView;
    @BindView(R.id.swipe_refresh_layout)
    SwipeRefreshLayout swipeRefreshLayout;

    private GalleryAdapter mGalleryAdapter;

    @Override
    protected int getContentView() {
        return R.layout.frag_list;
    }

    @Override
    protected void initView(View view) {
        setupRecyclerView();
    }

    @Override
    protected String getTitle() {
        return getString(R.string.gallery);
    }

    @Override
    protected boolean hasSearch() {
        return true;
    }

    private void setupRecyclerView() {
        swipeRefreshLayout.setColorSchemeResources(R.color.colorDark);
        swipeRefreshLayout.setOnRefreshListener(this);
        if (mGalleryAdapter == null) {
            mGalleryAdapter = new GalleryAdapter();
            mGalleryAdapter.setmItemGalleryClickListener(new GalleryAdapter.ItemGalleryClickListener() {
                @Override
                public void onProfileView(String userId) {
                    replaceFragment(ProfileFragment.newInstance(userId), true);
                }
            });
            mGalleryAdapter.setmOnViewImageListener(this);
        }
        recyclerView.setLayoutManager(new LinearLayoutManager(getActivityContext()));
        recyclerView.setAdapter(mGalleryAdapter);
        getPresenter().getListData();
    }

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return HomePresenter.class;
    }


    @Override
    public void onView(String url) {
        Intent intent = new Intent(getActivityContext(), ViewImageActivity.class);
        intent.putExtra("image_url", url);
        startActivity(intent);
    }

    @Override
    public void setList(ArrayList<Album> list) {
        mGalleryAdapter.setmListAlbums(list);
    }

    @Override
    public void onLoading() {
        super.onLoading();
        swipeRefreshLayout.setRefreshing(true);
    }

    @Override
    public void onLoadDone() {
        super.onLoadDone();
        swipeRefreshLayout.setRefreshing(false);
    }

    @Override
    public void onRefresh() {
        getPresenter().getListData();
    }

    @Override
    public void onResume() {
        super.onResume();
        getPresenter().getListData();
    }
}
