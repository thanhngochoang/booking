package com.paditech.mvpbase.screen.find_photographer;

import android.content.Intent;
import androidx.annotation.NonNull;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;
import androidx.appcompat.widget.AppCompatSpinner;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.TextView;

import com.google.android.gms.common.GooglePlayServicesNotAvailableException;
import com.google.android.gms.common.GooglePlayServicesRepairableException;
import com.google.android.libraries.places.api.model.Place;
import com.paditech.mvpbase.common.utils.get_location.PlacePickerHelper;
import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.dialog.DatePickerDialog;
import com.paditech.mvpbase.common.dialog.SelectItemDialog;
import com.paditech.mvpbase.common.model.PriceEnum;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.common.utils.Constant;
import com.paditech.mvpbase.screen.book.BookFragment;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;

import butterknife.BindView;
import butterknife.OnClick;

import static android.app.Activity.RESULT_OK;

/**
 * Created by ThanhNgocHoang on 11/15/2017.
 */

public class FindPhotographerFragment extends MVPFragment<FindPhotographerContact.PresenterViewOps>
        implements FindPhotographerContact.ViewOps, PhotographerAdapter.OnBookClickListener {
    private static int PLACE_PICKER_REQUEST = 1;
    private static String[] RANGE_PRICE = {"< 200K", "200K-500K", "500K-1M", "> 1M"};

    @BindView(R.id.recycler_view)
    RecyclerView recyclerView;
    @BindView(R.id.btn_pick_addr)
    TextView tvPickAddr;
    @BindView(R.id.tv_time)
    TextView tvTime;
    @BindView(R.id.tv_date)
    TextView tvDate;
    @BindView(R.id.tv_total_count)
    TextView tvTotalCount;
    @BindView(R.id.swipe_refresh_layout)
    SwipeRefreshLayout swipeRefreshLayout;
    @BindView(R.id.tv_price)
    TextView tvPrice;

    private Place mSelectedPlace;
    private Date mSelectedDate;
    private PhotographerAdapter mPhotographerAdapter;
    private PriceEnum mSelectedPrice = PriceEnum.PRICE_1;

    @Override
    protected int getContentView() {
        return R.layout.frag_find_photographer;
    }

    @Override
    protected void initView(View view) {
        mSelectedDate = Calendar.getInstance().getTime();
        tvPrice.setText(mSelectedPrice.getText());
        swipeRefreshLayout.setColorSchemeResources(R.color.blue);
        setupDate(mSelectedDate);
        if (mPhotographerAdapter == null) {
            mPhotographerAdapter = new PhotographerAdapter();
            mPhotographerAdapter.setmOnBookClickListener(this);
        }
        recyclerView.setLayoutManager(new LinearLayoutManager(getActivityContext()));
        recyclerView.setAdapter(mPhotographerAdapter);
    }

    @Override
    protected String getTitle() {
        return getString(R.string.find_photographer);
    }


    @Override
    protected boolean hasSearch() {
        return false;
    }

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return FindPhotographerPresenter.class;
    }

    @OnClick({R.id.btn_request, R.id.btn_time, R.id.btn_date, R.id.btn_search, R.id.btn_pick_addr})
    public void onViewClicked(View view) {
        switch (view.getId()) {
            case R.id.btn_request:
                SelectItemDialog.show(getFragmentManager(), getString(R.string.enter_price), new SelectItemDialog.OnSelectRangePriceListener() {
                    @Override
                    public void onSelectPrice(PriceEnum price) {
                        mSelectedPrice = price;
                        tvPrice.setText(mSelectedPrice.getText());
                    }
                });
                break;
            case R.id.btn_time:
                break;
            case R.id.btn_date:
                DatePickerDialog.show(getFragmentManager(), new DatePickerDialog.OnDateTimePickerListener() {
                    @Override
                    public void onSelectedDate(Date date) {
                        mSelectedDate = date;
                        setupDate(date);
                    }
                });
                break;
            case R.id.btn_search:
                if (validate())
                    getPresenter().onSearchPhotographers(mSelectedPlace.getLatLng().latitude, mSelectedPlace.getLatLng().longitude, 1);
                break;
            case R.id.btn_pick_addr:
                startActivityForResult(PlacePickerHelper.buildIntent(getActivity()), PLACE_PICKER_REQUEST);
                break;
        }
    }

    private boolean validate() {
        if (mSelectedPlace == null) {
            showToast(getString(R.string.selected_place_empty));
            return false;
        }
        return true;
    }

    private void setupDate(Date date) {
        tvDate.setText(Constant.FIND_DATE_FORMAT.format(date));
    }


    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == PLACE_PICKER_REQUEST) {
            if (resultCode == RESULT_OK) {
                Place place = PlacePickerHelper.getPlace(data);
                if (place != null) {
                    this.mSelectedPlace = place;
                    tvPickAddr.setText(place.getName());
                }
            }
        }
    }

    @Override
    public void onSearchResults(ArrayList<User> photographers) {
        if (photographers == null) return;
        mPhotographerAdapter.setmListPhotographers(photographers);
        tvTotalCount.setText(String.format(getString(R.string.find_total_count), photographers.size()));
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
    public void onBook(User photographer) {
        replaceFragment(BookFragment.newInstance(photographer, mSelectedPlace, mSelectedDate,
                (mSelectedPrice.getMin() + mSelectedPrice.getMax()) / 2), true);
    }
}
