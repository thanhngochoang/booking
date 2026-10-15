package com.paditech.mvpbase.screen.my_project.list_booking;

import com.google.android.material.floatingactionbutton.FloatingActionButton;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
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

public class ListBookingFragment extends MVPFragment<ListBookingContact.PresenterViewOps>
        implements ListBookingContact.ViewOps, SwipeRefreshLayout.OnRefreshListener {
    public static final int BOOKING = 0;
    public static final int PROJECT = 1;

    @BindView(R.id.recycler_view)
    RecyclerView recyclerView;
    @BindView(R.id.swipe_refresh_layout)
    SwipeRefreshLayout swipeRefreshLayout;

    private MyProjectAdapter mMyProjectAdapter;
    private int mType;

    public static ListBookingFragment newInstance(int type) {
        ListBookingFragment fragment = new ListBookingFragment();
        fragment.mType = type;
        return fragment;
    }

    @Override
    public void onRefresh() {
        if (mType == BOOKING) getPresenter().getBookingHistory();
        else getPresenter().getListProjects();
    }

    @Override
    public void updateBookingList(ArrayList<Booking> bookings) {
        mMyProjectAdapter.setmListBooking(bookings);
    }

    @Override
    public void updateProjects(ArrayList<Booking> projects) {
        mMyProjectAdapter.setmListBooking(projects);
    }

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return ListBookingPresenter.class;
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
                replaceFragment(CreateProjectFragment.newInstance(booking, true), true);
            }

            @Override
            public void onAttend(Booking booking) {

            }
        });
        swipeRefreshLayout.setColorSchemeResources(R.color.colorDark);
        swipeRefreshLayout.setOnRefreshListener(this);
        recyclerView.setLayoutManager(new LinearLayoutManager(getActivityContext()));
        recyclerView.setAdapter(mMyProjectAdapter);
        onRefresh();
    }

    @Override
    protected String getTitle() {
        return null;
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
}
