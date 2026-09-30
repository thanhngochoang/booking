package com.paditech.mvpbase.screen.find_project;

import android.support.v4.widget.SwipeRefreshLayout;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.View;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.screen.create_project.CreateProjectFragment;
import com.paditech.mvpbase.screen.my_project.MyProjectAdapter;

import java.util.ArrayList;

import butterknife.BindView;

/**
 * Created by Nha Nha on 1/3/2018.
 */

public class FindProjectFragment extends MVPFragment<FindProjectContact.PresenterViewOps>
        implements FindProjectContact.ViewOps, SwipeRefreshLayout.OnRefreshListener {
    @BindView(R.id.recycler_view)
    RecyclerView recyclerView;
    @BindView(R.id.swipe_refresh_layout)
    SwipeRefreshLayout swipeRefreshLayout;

    private MyProjectAdapter mMyProjectAdapter;

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return FindProjectPresenter.class;
    }

    @Override
    protected int getContentView() {
        return R.layout.frag_list;
    }

    @Override
    protected void initView(View view) {
        mMyProjectAdapter = new MyProjectAdapter();
        mMyProjectAdapter.setmBookClickListener(new MyProjectAdapter.OnItemBookClickListener() {
            @Override
            public void onEdit(Booking booking) {

            }

            @Override
            public void onAttend(Booking booking) {
                replaceFragment(CreateProjectFragment.newInstance(booking, false), true);
            }
        });
        swipeRefreshLayout.setColorSchemeResources(R.color.colorDark);
        swipeRefreshLayout.setOnRefreshListener(this);
        recyclerView.setLayoutManager(new LinearLayoutManager(getActivityContext()));
        recyclerView.setAdapter(mMyProjectAdapter);
        getPresenter().getListProjects();
    }

    @Override
    protected String getTitle() {
        return getString(R.string.find_project);
    }

    @Override
    public void updateProjects(ArrayList<Booking> projects) {
        mMyProjectAdapter.setmListBooking(projects);
    }

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
        getPresenter().getListProjects();
    }
}
