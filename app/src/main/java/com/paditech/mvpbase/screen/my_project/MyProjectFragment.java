package com.paditech.mvpbase.screen.my_project;

import android.support.annotation.Nullable;
import android.support.design.widget.FloatingActionButton;
import android.support.design.widget.TabLayout;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentStatePagerAdapter;
import android.support.v4.view.ViewPager;
import android.support.v4.widget.SwipeRefreshLayout;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.View;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.screen.create_project.CreateProjectFragment;
import com.paditech.mvpbase.screen.my_project.list_booking.ListBookingFragment;

import java.util.ArrayList;

import butterknife.BindView;
import butterknife.OnClick;

/**
 * Created by ThanhNgocHoang on 12/25/2017.
 */

public class MyProjectFragment extends MVPFragment<MyProjectContact.PresenterViewOps>
        implements MyProjectContact.ViewOps {
    @BindView(R.id.view_pager)
    ViewPager viewPager;
    @BindView(R.id.btn_create)
    FloatingActionButton btnCreate;
    @BindView(R.id.tab_layout)
    TabLayout tabLayout;

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return MyProjectPresenter.class;
    }

    @Override
    protected int getContentView() {
        return R.layout.frag_pager;
    }

    @Override
    protected void initView(View view) {
        btnCreate.setVisibility(View.VISIBLE);
        viewPager.setAdapter(new BookPageAdapter(getChildFragmentManager()));
        tabLayout.setupWithViewPager(viewPager);
    }

    @Override
    protected String getTitle() {
        return getString(R.string.my_project);
    }


    @OnClick(R.id.btn_create)
    public void onCreateProjectClick() {
        replaceFragment(CreateProjectFragment.newInstance(), true);
    }

    private class BookPageAdapter extends FragmentStatePagerAdapter {

        public BookPageAdapter(FragmentManager fm) {
            super(fm);
        }

        @Override
        public Fragment getItem(int position) {
            return ListBookingFragment.newInstance(position);
        }

        @Override
        public int getCount() {
            return 2;
        }

        @Nullable
        @Override
        public CharSequence getPageTitle(int position) {
            if(position==0) return "My Bookings";
            else return "My Projects";
        }
    }
}
