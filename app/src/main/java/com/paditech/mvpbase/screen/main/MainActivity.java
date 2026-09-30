package com.paditech.mvpbase.screen.main;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.os.Bundle;
import android.support.annotation.Nullable;
import android.support.design.widget.NavigationView;
import android.support.v4.widget.DrawerLayout;
import android.support.v7.app.ActionBarDrawerToggle;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.support.v7.widget.Toolbar;
import android.view.Gravity;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.event.OnUpdateCalendarEvent;
import com.paditech.mvpbase.common.event.OnUpdateMessagesEvent;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenter;
import com.paditech.mvpbase.common.mvp.activity.MVPActivity;
import com.paditech.mvpbase.common.utils.ImageUtil;
import com.paditech.mvpbase.common.utils.PrefUtil;
import com.paditech.mvpbase.common.view.BadgeDrawerArrowDrawable;
import com.paditech.mvpbase.screen.calendar.CalendarFragment;
import com.paditech.mvpbase.screen.find_project.FindProjectFragment;
import com.paditech.mvpbase.screen.my_project.MyProjectFragment;
import com.paditech.mvpbase.screen.profile.ProfileFragment;
import com.paditech.mvpbase.screen.album.AlbumFragment;
import com.paditech.mvpbase.screen.find_photographer.FindPhotographerFragment;
import com.paditech.mvpbase.screen.home.HomeFragment;
import com.paditech.mvpbase.screen.list_messenger.ListMessengerFragment;
import com.paditech.mvpbase.screen.login.LoginActivity;
import com.paditech.mvpbase.screen.main.menu.MenuAdapter;
import com.paditech.mvpbase.screen.main.menu.MenuType;
import com.paditech.mvpbase.screen.term_register.TernRegisterActivity;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import butterknife.BindView;
import butterknife.OnClick;
import de.hdodenhof.circleimageview.CircleImageView;

/**
 * Created by ThanhNgocHoang on 9/19/2017.
 */

public class MainActivity extends MVPActivity<MainContact.PresenterViewOps>
        implements MainContact.ViewOps, MenuAdapter.OnMenuSelectListener {
    @BindView(R.id.navigation_base)
    NavigationView navigationBase;
    @BindView(R.id.drawer_layout)
    DrawerLayout drawerLayout;
    @BindView(R.id.avatar)
    CircleImageView avatar;
    @BindView(R.id.tv_name)
    TextView tvName;
    @BindView(R.id.tv_address)
    TextView tvAddress;
    @BindView(R.id.recycler_view)
    RecyclerView recyclerView;
    @BindView(R.id.tool_bar)
    Toolbar toolBar;
    @BindView(R.id.tv_title)
    TextView tvTitle;

    private MenuItem btnSearch;
    private ActionBarDrawerToggle toggle;
    private BadgeDrawerArrowDrawable badgeDrawable;
    private MenuAdapter mMenuAdapter;
    private int mCountMess = 0, mCountCalendar = 0;

    @Override
    protected int getContentView() {
        return R.layout.activity_main;
    }

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EventBus.getDefault().register(this);
    }

    @Override
    protected void onDestroy() {
        EventBus.getDefault().unregister(this);
        super.onDestroy();
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onUpdateMessageEvent(OnUpdateMessagesEvent event) {
        try {
            if (badgeDrawable != null) {
                mCountMess = getPresenter().getBadgeCountMess();
                if (mMenuAdapter != null) mMenuAdapter.setCountMess(mCountMess);
                if (mCountMess + mCountCalendar > 0) {
                    badgeDrawable.setText(String.valueOf(mCountMess + mCountCalendar));
                    badgeDrawable.setEnabled(true);
                } else badgeDrawable.setEnabled(false);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onUpdateCalendar(OnUpdateCalendarEvent event) {
        try {
            if (badgeDrawable != null) {
                mCountCalendar = getPresenter().getBadgeCountCalendar();
                if (mMenuAdapter != null) mMenuAdapter.setmCountCalendar(mCountCalendar);
                if (mCountMess + mCountCalendar > 0) {
                    badgeDrawable.setText(String.valueOf(mCountMess + mCountCalendar));
                    badgeDrawable.setEnabled(true);
                } else badgeDrawable.setEnabled(false);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    protected void initView() {
        setToolbar();
        setupProfile();
        setupMenuRecyclerView();
        replaceFragment(new HomeFragment(), false);
        onUpdateMessageEvent(new OnUpdateMessagesEvent());
        onUpdateCalendar(new OnUpdateCalendarEvent());
    }


    public void setSearchIcon(boolean show) {
        if (btnSearch != null) btnSearch.setVisible(show);
    }

    public void setupTitleHeader(String text) {
        tvTitle.setText(text);
    }

    private void setToolbar() {
        setSupportActionBar(toolBar);
        setTitle("");
        toggle = new ActionBarDrawerToggle(this, drawerLayout, toolBar, R.string.open_drawer, R.string.close_drawer) {
        };
        badgeDrawable = new BadgeDrawerArrowDrawable(getSupportActionBar().getThemedContext());
        toggle.setDrawerArrowDrawable(badgeDrawable);
        toggle.syncState();
        drawerLayout.addDrawerListener(toggle);
    }

    private void setupProfile() {
        //Fake profile o left menu
        if (PrefUtil.isLogin()) {
            User user = PrefUtil.getUser(this);
            if (user != null) {
                ImageUtil.loadImage(this, user.getAvatar(), avatar);
                tvAddress.setText(user.getAddress());
                tvName.setText(user.getFull_name());
            }
        }
    }

    private void setupMenuRecyclerView() {
        // cai dat list cac chuc nang trong left menu
        mMenuAdapter = new MenuAdapter(PrefUtil.isPhotographer(this));
        mMenuAdapter.setmOnMenuSelectListener(this);
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        recyclerView.setAdapter(mMenuAdapter);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_home, menu);
        btnSearch = menu.findItem(R.id.btn_search);
        return super.onCreateOptionsMenu(menu);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();
        switch (id) {
            case R.id.btn_search:
                drawerLayout.closeDrawer(Gravity.LEFT);
                replaceFragment(new FindPhotographerFragment(), true);
                break;
        }
        return super.onOptionsItemSelected(item);
    }

    @Override
    protected Class<? extends ActivityPresenter> onRegisterPresenter() {
        return MainPresenter.class;
    }

    @OnClick(R.id.profile_layout)
    public void onClickProfile() {
        drawerLayout.closeDrawer(Gravity.LEFT);
        replaceFragment(ProfileFragment.newInstance(), true);
    }

    @Override
    public void onSelectedPhotographerMenu(MenuType.PhotographerMenu menuType) {
        drawerLayout.closeDrawer(Gravity.LEFT);
        switch (menuType) {
            case HELP:
                break;
            case ABOUT:
                // replaceFragment(ProfileFragment.newInstance(), true);
                break;
            case MY_PROJECT:
                replaceFragment(new MyProjectFragment(), true);
                break;
            case PROFILE:
                replaceFragment(ProfileFragment.newInstance(), true);
                break;
            case CALENDAR:
                replaceFragment(new CalendarFragment(), true);
                break;
            case AlBUMS:
                replaceFragment(new AlbumFragment(), true);
                break;
            case MESSAGES:
                replaceFragment(new ListMessengerFragment(), true);
                break;
            case FIND_PROJECT:
                replaceFragment(new FindProjectFragment(), true);
                break;
            case SETTINGS:
                break;
            case LOGOUT:
                PrefUtil.logout(this);
                Intent intent = new Intent(this, LoginActivity.class);
                intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                startActivity(intent);
                finish();
                break;
        }
    }


    @Override
    public void onSelectedUserMenu(MenuType.UserMenu menuType) {
        drawerLayout.closeDrawer(Gravity.LEFT);
        switch (menuType) {
            case HELP:
                break;
            case ABOUT:
                // replaceFragment(ProfileFragment.newInstance(), true);
                // Log.e("Nha", "Nha");
                break;
            case PROFILE:
                replaceFragment(ProfileFragment.newInstance(), true);
                break;
            case MY_PROJECT:
                replaceFragment(new MyProjectFragment(), true);
                break;
            case MESSAGES:
                replaceFragment(new ListMessengerFragment(), true);
                break;
            case SETTINGS:
                break;
            case BECOME_PHOTOGRAPHER:
                Intent intent = new Intent(this, TernRegisterActivity.class);
                startActivity(intent);
                break;
            case LOGOUT:
                PrefUtil.logout(this);
                Intent intent_logout = new Intent(this, LoginActivity.class);
                intent_logout.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                startActivity(intent_logout);
                finish();
                break;
            case CALENDAR:
                replaceFragment(new CalendarFragment(), true);
                break;
        }
    }

    @SuppressLint("RtlHardcoded")
    @Override
    public void onBackPressed() {
        if (drawerLayout.isDrawerOpen(Gravity.LEFT)) {
            drawerLayout.closeDrawer(Gravity.LEFT);
        } else super.onBackPressed();
    }
}
