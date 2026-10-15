package com.paditech.mvpbase.screen.book;

import android.content.Intent;
import android.os.Bundle;
import androidx.appcompat.widget.AppCompatRatingBar;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.LinearSnapHelper;
import androidx.recyclerview.widget.RecyclerView;
import androidx.recyclerview.widget.SnapHelper;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
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
import com.paditech.mvpbase.screen.messenger.MessengerFragment;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;

import butterknife.BindView;
import butterknife.ButterKnife;
import butterknife.OnClick;
import butterknife.Unbinder;
import de.hdodenhof.circleimageview.CircleImageView;

import static android.app.Activity.RESULT_OK;

/**
 * Created by ThanhNgocHoang on 12/7/2017.
 */

public class BookFragment extends MVPFragment<BookContact.PresenterViewOps> implements BookContact.ViewOps {
    private static int PLACE_PICKER_REQUEST = 1;

    @BindView(R.id.avatar)
    CircleImageView avatar;
    @BindView(R.id.tv_name)
    TextView tvName;
    @BindView(R.id.tv_star)
    AppCompatRatingBar tvStar;
    @BindView(R.id.tv_address)
    TextView tvAddress;
    @BindView(R.id.cover)
    ImageView cover;
    @BindView(R.id.recycler_view_date)
    RecyclerView recyclerViewDate;
    @BindView(R.id.btn_pick_addr)
    TextView btnPickAddress;
    @BindView(R.id.tv_price)
    TextView tvPrice;
    @BindView(R.id.tv_month)
    TextView tvMonth;
    @BindView(R.id.tv_time)
    TextView tvTime;
    @BindView(R.id.tv_start_time)
    TextView tvStartTime;
    @BindView(R.id.tv_end_time)
    TextView tvEndTime;
    @BindView(R.id.view_2)
    LinearLayout view2;
    @BindView(R.id.btn_book)
    Button btnBook;
    @BindView(R.id.btn_deny)
    Button btnDeny;
    @BindView(R.id.btn_send_message)
    View btnSendMessage;

    private User mPhotographer;
    private DateAdapter mDateAdapter;
    private Place mSelectedPlace;
    private long mSelectedPrice = 0;
    private Calendar mStartDate, mEndDate;
    private Booking mBooking;

    public static BookFragment newInstance(User photographer, Place mSelectedPlace, Date mSelectedDate, long mSelectedPrice) {
        BookFragment bookFragment = new BookFragment();
        bookFragment.mPhotographer = photographer;
        bookFragment.mSelectedPlace = mSelectedPlace;
        if (mSelectedDate == null) mSelectedDate = Calendar.getInstance().getTime();
        Calendar start = Calendar.getInstance();
        start.setTime(mSelectedDate);
        start.set(Calendar.HOUR_OF_DAY, 8);
        bookFragment.mStartDate = start;

        Calendar end = Calendar.getInstance();
        end.setTime(mSelectedDate);
        end.set(Calendar.HOUR_OF_DAY, 17);
        bookFragment.mEndDate = end;

        bookFragment.mSelectedPrice = mSelectedPrice;
        return bookFragment;
    }

    public static BookFragment newInstance(Booking booking) {
        BookFragment bookFragment = new BookFragment();
        bookFragment.mBooking = booking;
        return bookFragment;
    }

    @Override
    protected int getContentView() {
        return R.layout.frag_book;
    }

    @Override
    protected void initView(View view) {
        setupRecyclerView();
        setupData();
    }


    private void setupData() {
        if (mBooking != null) {
            btnSendMessage.setVisibility(View.GONE);
            tvPrice.setText(StringUtil.getPriceVNDCurrency(mBooking.getPrice()));
            btnPickAddress.setText(mBooking.getAddress_name());
            tvStartTime.setText(Constant.BOOK_TIME_FORMAT.format(mBooking.getStart_time()));
            tvEndTime.setText(Constant.BOOK_TIME_FORMAT.format(mBooking.getEnd_time()));
            tvMonth.setText(Constant.BOOK_MONTH_FORMAT.format(mBooking.getStart_time()));
            if(mBooking.getPhotographer_id().equals(PrefUtil.getUid())) {
                if (mBooking.getStatus() == BookStatus.WAITING) {
                    btnBook.setText(R.string.accept);
                    btnDeny.setVisibility(View.VISIBLE);
                } else {
                    btnBook.setVisibility(View.GONE);
                    btnDeny.setVisibility(View.GONE);
                }
            } else {
                btnDeny.setVisibility(View.GONE);
                btnBook.setVisibility(View.GONE);
            }
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
            if (mPhotographer != null) {
                ImageUtil.loadImage(getActivityContext(), mPhotographer.getAvatar(), avatar);
                tvName.setText(mPhotographer.getFull_name());
                tvStar.setRating((float) mPhotographer.getRate());
                tvAddress.setText(mPhotographer.getAddress());
                getPresenter().getCover(mPhotographer.getId());
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
        if (mBooking != null) return getString(R.string.booking_detail);
        else return getString(R.string.book_title);
    }

    @Override
    protected boolean hasSearch() {
        return true;
    }

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return BookPresenter.class;
    }

    @Override
    public void updateCover(String coverUrl) {
        //ImageUtil.loadImage(getActivityContext(), coverUrl, cover);
    }

    @Override
    public void onBookSuccess() {
        showToast(getString(R.string.mess_book_success));
        if (getActivity() != null)
            getActivity().onBackPressed();
    }

    @Override
    public void onDeniedSuccess() {
        getActivityReference().onBackPressed();
    }

    @Override
    public void onAcceptedSuccess() {
        showToast(getString(R.string.accept_book_success));
    }

    @Override
    public void onFailed(String message) {

    }


    @OnClick(R.id.btn_send_message)
    public void onViewClicked() {
        replaceFragment(MessengerFragment.newInstance(mPhotographer), true);
    }

    @OnClick(R.id.tv_price)
    public void onPriceClick() {
        if (mBooking == null) {
            SelectItemDialog.show(getFragmentManager(), getString(R.string.choose_enter_price), new SelectItemDialog.OnSelectPriceListener() {
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

    @OnClick(R.id.btn_deny)
    public void onDenyBooking() {
        if (mBooking != null) {
            getPresenter().denyBooking(mBooking);
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

    @OnClick(R.id.btn_book)
    public void onBookClick() {
        try {
            if (mBooking == null) {
                Booking booking = new Booking(mPhotographer.getId(), PrefUtil.getUid(), mStartDate.getTime(),
                        mEndDate.getTime(), mSelectedPlace.getLatLng().latitude,
                        mSelectedPlace.getLatLng().longitude,
                        String.valueOf(mSelectedPlace.getAddress()), mSelectedPrice);
                getPresenter().onBook(booking);
            } else {
                getPresenter().acceptBooking(mBooking);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

    }

    @OnClick({R.id.btn_request, R.id.btn_time, R.id.btn_start_time, R.id.btn_end_time})
    public void onViewClicked(View view) {
        switch (view.getId()) {
            case R.id.btn_request:
                break;
            case R.id.btn_time:
                break;
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
        }
    }
}
