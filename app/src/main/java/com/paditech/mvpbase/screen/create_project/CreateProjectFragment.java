package com.paditech.mvpbase.screen.create_project;

import android.content.Intent;
import androidx.appcompat.widget.AppCompatRatingBar;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.LinearSnapHelper;
import androidx.recyclerview.widget.RecyclerView;
import androidx.recyclerview.widget.SnapHelper;
import android.util.Log;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

import com.google.android.gms.common.GooglePlayServicesNotAvailableException;
import com.google.android.gms.common.GooglePlayServicesRepairableException;
import com.google.android.libraries.places.api.model.Place;
import com.paditech.mvpbase.common.utils.get_location.PlacePickerHelper;
import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.dialog.SelectItemDialog;
import com.paditech.mvpbase.common.dialog.TimePickerDialog;
import com.paditech.mvpbase.common.model.BookStatus;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.common.utils.Constant;
import com.paditech.mvpbase.common.utils.ImageUtil;
import com.paditech.mvpbase.common.utils.PrefUtil;
import com.paditech.mvpbase.common.utils.StringUtil;
import com.paditech.mvpbase.screen.book.DateAdapter;
import com.paditech.mvpbase.screen.book.DateSnapHelper;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;

import butterknife.BindView;
import butterknife.OnClick;
import de.hdodenhof.circleimageview.CircleImageView;

import static android.app.Activity.RESULT_OK;

/**
 * Created by Nha Nha on 1/3/2018.
 */

public class CreateProjectFragment extends MVPFragment<CreateProjectContact.PresenterViewOps> implements CreateProjectContact.ViewOps {
    private static int PLACE_PICKER_REQUEST = 1;

    @BindView(R.id.cover)
    ImageView cover;
    @BindView(R.id.avatar)
    CircleImageView avatar;
    @BindView(R.id.tv_name)
    TextView tvName;
    @BindView(R.id.tv_star)
    AppCompatRatingBar tvStar;
    @BindView(R.id.tv_address)
    TextView tvAddress;
    @BindView(R.id.recycler_view_date)
    RecyclerView recyclerViewDate;
    @BindView(R.id.tv_month)
    TextView tvMonth;
    @BindView(R.id.tv_price)
    TextView tvPrice;
    @BindView(R.id.tv_time)
    TextView tvTime;
    @BindView(R.id.tv_start_time)
    TextView tvStartTime;
    @BindView(R.id.tv_end_time)
    TextView tvEndTime;
    @BindView(R.id.btn_hire)
    TextView btnHire;
    @BindView(R.id.btn_pick_addr)
    TextView btnPickAddress;

    private DateAdapter mDateAdapter;
    private Place mSelectedPlace;
    private long mSelectedPrice = 0;
    private Calendar mStartDate, mEndDate;
    private Booking mBooking;
    private boolean isEdit;

    public static CreateProjectFragment newInstance() {
        CreateProjectFragment bookFragment = new CreateProjectFragment();
        Calendar start = Calendar.getInstance();
        start.set(Calendar.HOUR_OF_DAY, 8);
        bookFragment.mStartDate = start;

        Calendar end = Calendar.getInstance();
        end.set(Calendar.HOUR_OF_DAY, 17);
        bookFragment.mEndDate = end;

        return bookFragment;
    }

    public static CreateProjectFragment newInstance(Booking booking, boolean isEdit) {
        CreateProjectFragment bookFragment = new CreateProjectFragment();
        bookFragment.mBooking = booking;
        bookFragment.isEdit = isEdit;
        return bookFragment;
    }

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return CreateProjectPresenter.class;
    }

    @Override
    protected int getContentView() {
        return R.layout.frag_create_project;
    }

    @Override
    protected void initView(View view) {
        setupRecyclerView();
        setupData();
    }

    private void setupData() {
        if (mBooking != null) {
            btnHire.setBackgroundResource(R.drawable.bg_red_small_border_selector);
            if (isEdit) {
                btnHire.setText("Close Project");
            } else {
                btnHire.setText("Attend Project");
            }
            tvPrice.setText(StringUtil.getPriceVNDCurrency(mBooking.getPrice()));
            btnPickAddress.setText(mBooking.getAddress_name());
            tvStartTime.setText(Constant.BOOK_TIME_FORMAT.format(mBooking.getStart_time()));
            tvEndTime.setText(Constant.BOOK_TIME_FORMAT.format(mBooking.getEnd_time()));
            tvMonth.setText(Constant.BOOK_MONTH_FORMAT.format(mBooking.getStart_time()));
        } else {
            if (mStartDate == null) {
                mStartDate = Calendar.getInstance();
                mStartDate.set(Calendar.HOUR_OF_DAY, 8);
            }
            if (mEndDate == null) {
                mEndDate = Calendar.getInstance();
                mEndDate.set(Calendar.HOUR_OF_DAY, 17);
            }
            tvStartTime.setText(Constant.BOOK_TIME_FORMAT.format(mStartDate.getTime()));
            tvEndTime.setText(Constant.BOOK_TIME_FORMAT.format(mEndDate.getTime()));
            tvMonth.setText(Constant.BOOK_MONTH_FORMAT.format(mStartDate.getTime()));
            User user = PrefUtil.getUser(getActivityContext());
            if (user != null) {
                ImageUtil.loadImage(getActivityContext(), user.getAvatar(), avatar);
                tvName.setText(user.getFull_name());
                tvStar.setRating((float) user.getRate());
                tvAddress.setText(user.getAddress());
            }
        }
    }

    private void setupRecyclerView() {
        mDateAdapter = new DateAdapter(mBooking == null ? mStartDate.getTime() : mBooking.getStart_time());
        DateSnapHelper dateSnapHelper = new DateSnapHelper(getActivityContext(), LinearLayoutManager.HORIZONTAL, false);
        recyclerViewDate.setLayoutManager(dateSnapHelper);
        recyclerViewDate.setAdapter(mDateAdapter);
        SnapHelper snapHelper = new LinearSnapHelper();
        snapHelper.attachToRecyclerView(recyclerViewDate);
        if (mBooking != null) {
            recyclerViewDate.setNestedScrollingEnabled(false);
            dateSnapHelper.setScrollable(false);
        }
        recyclerViewDate.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrolled(RecyclerView recyclerView, int dx, int dy) {
                super.onScrolled(recyclerView, dx, dy);
            }

            @Override
            public void onScrollStateChanged(RecyclerView recyclerView, int newState) {
                super.onScrollStateChanged(recyclerView, newState);
                if (newState == RecyclerView.SCROLL_STATE_IDLE) {
                    int center = (((LinearLayoutManager) recyclerView.getLayoutManager()).findFirstVisibleItemPosition()
                            + ((LinearLayoutManager) recyclerView.getLayoutManager()).findLastVisibleItemPosition()) / 2;
                    Log.e("CENTER", center + "");
                    mStartDate.add(Calendar.DAY_OF_MONTH, center - (mDateAdapter.getItemCount() / 2));
                    mEndDate.add(Calendar.DAY_OF_MONTH, center - (mDateAdapter.getItemCount() / 2));
                    tvMonth.setText(new SimpleDateFormat("'Tháng' MM, yyyy").format(mStartDate.getTime()));
                }
            }
        });
        recyclerViewDate.post(new Runnable() {
            @Override
            public void run() {
                recyclerViewDate.scrollToPosition(mDateAdapter.getItemCount() / 2);
            }
        });
    }


    @Override
    protected String getTitle() {
        return getString(R.string.create_project);
    }


    @OnClick({R.id.btn_pick_addr, R.id.btn_request, R.id.btn_time, R.id.btn_start_time, R.id.btn_end_time, R.id.btn_hire})
    public void onViewClicked(View view) {
        switch (view.getId()) {
            case R.id.btn_start_time:
                TimePickerDialog.show(getFragmentManager(), new TimePickerDialog.OnTimePickerListener() {
                    @Override
                    public void onSelectedTime(int hour, int minute) {
                        mStartDate.set(Calendar.HOUR_OF_DAY, hour);
                        mStartDate.set(Calendar.MINUTE, minute);
                        tvStartTime.setText(Constant.BOOK_TIME_FORMAT.format(mStartDate.getTime()));
                    }
                });
                break;
            case R.id.btn_end_time:
                TimePickerDialog.show(getFragmentManager(), new TimePickerDialog.OnTimePickerListener() {
                    @Override
                    public void onSelectedTime(int hour, int minute) {
                        mEndDate.set(Calendar.HOUR_OF_DAY, hour);
                        mEndDate.set(Calendar.MINUTE, minute);
                        tvEndTime.setText(Constant.BOOK_TIME_FORMAT.format(mEndDate.getTime()));
                    }
                });
                break;
            case R.id.btn_pick_addr:
                break;
            case R.id.btn_request:
                break;
            case R.id.btn_time:
                break;
            case R.id.btn_hire:
                try {
                    if (mBooking == null) {
                        if (mSelectedPlace == null) {
                            showError("Vui lòng chọn địa điểm chụp để tiếp tục!");
                            return;
                        }
                        Booking booking = new Booking(PrefUtil.getUid(), null, mStartDate.getTime(),
                                mEndDate.getTime(), mSelectedPlace.getLatLng().latitude,
                                mSelectedPlace.getLatLng().longitude,
                                String.valueOf(mSelectedPlace.getAddress()), mSelectedPrice);
                        booking.setStatus(BookStatus.OPENED.getStatus());
                        booking.setIs_photographer_project(true);
                        getPresenter().createProject(booking);
                    } else {
                        if (isEdit) getPresenter().onCloseProject(mBooking);
                        else getPresenter().onJoinProject(mBooking);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
                break;
        }
    }

    @OnClick(R.id.tv_price)
    public void onPriceClick() {
        if (mBooking == null) {
            SelectItemDialog.show(getChildFragmentManager(), getString(R.string.choose_enter_price), new SelectItemDialog.OnSelectPriceListener() {
                @Override
                public void onSelectPrice(long price) {
                    mSelectedPrice = price;
                    tvPrice.setText(StringUtil.getPriceVNDCurrency(price));
                }
            });
        }
    }

    @OnClick(R.id.btn_pick_addr)
    public void onPickAddress() {
        if (mBooking == null) {
            startActivityForResult(PlacePickerHelper.buildIntent(getActivity()), PLACE_PICKER_REQUEST);
        }
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == PLACE_PICKER_REQUEST) {
            if (resultCode == RESULT_OK) {
                Place place = PlacePickerHelper.getPlace(data);
                if (place != null) {
                    this.mSelectedPlace = place;
                    btnPickAddress.setText(place.getName());
                }
            }
        }
    }

    @Override
    public void onSuccess() {
        getActivity().onBackPressed();
    }
}
