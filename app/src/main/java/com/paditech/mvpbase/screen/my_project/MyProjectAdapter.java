package com.paditech.mvpbase.screen.my_project;

import androidx.appcompat.widget.AppCompatRatingBar;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.firebase.FirebaseHelper;
import com.paditech.mvpbase.common.firebase.GetUserInfoListener;
import com.paditech.mvpbase.common.model.BookStatus;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.utils.Constant;
import com.paditech.mvpbase.common.utils.PrefUtil;
import com.paditech.mvpbase.common.utils.StringUtil;

import java.util.ArrayList;
import java.util.Date;

import butterknife.BindView;
import butterknife.ButterKnife;

/**
 * Created by ThanhNgocHoang on 12/25/2017.
 */

public class MyProjectAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    private ArrayList<Booking> mListBooking;
    private OnItemBookClickListener mBookClickListener;

    public void setmBookClickListener(OnItemBookClickListener mBookClickListener) {
        this.mBookClickListener = mBookClickListener;
    }

    public MyProjectAdapter() {
        mListBooking = new ArrayList<>();
    }

    public void setmListBooking(ArrayList<Booking> mListBooking) {
        this.mListBooking = mListBooking;
        notifyDataSetChanged();
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        return new MyProjectHolder(LayoutInflater.from(parent.getContext()).inflate(R.layout.item_my_project, parent, false));
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        MyProjectHolder myProjectHolder = (MyProjectHolder) holder;
        myProjectHolder.bindData(position);
    }

    @Override
    public int getItemCount() {
        if (mListBooking != null) return mListBooking.size();
        return 0;
    }

    protected class MyProjectHolder extends RecyclerView.ViewHolder {
        @BindView(R.id.tv_status)
        Button tvStatus;
        @BindView(R.id.tv_name)
        TextView tvName;
        @BindView(R.id.tv_star)
        AppCompatRatingBar tvStar;
        @BindView(R.id.tv_address)
        TextView tvAddress;
        @BindView(R.id.tv_price)
        TextView tvPrice;
        @BindView(R.id.tv_date)
        TextView tvDate;
        @BindView(R.id.tv_time)
        TextView tvTime;
        @BindView(R.id.recycler_view)
        RecyclerView recyclerView;

        private ListUserAdapter mUserAdapter;

        public MyProjectHolder(View itemView) {
            super(itemView);
            ButterKnife.bind(this, itemView);
            mUserAdapter = new ListUserAdapter();
            recyclerView.setLayoutManager(new LinearLayoutManager(itemView.getContext(), LinearLayoutManager.HORIZONTAL, false));
            recyclerView.setAdapter(mUserAdapter);
        }

        private void bindData(final int pos) {
            try {
                final Booking booking = mListBooking.get(pos);
                if (StringUtil.isEmpty(booking.getPhotographer_name())) {
                    FirebaseHelper.getUserInfo(booking.getPhotographer_id(), new GetUserInfoListener() {
                        @Override
                        public void getUserInfo(User user) {
                            if (user != null) {
                                booking.setPhotographer_name(user.getFull_name());
                                mListBooking.set(pos, booking);
                                notifyDataSetChanged();
                            }
                        }
                    });
                } else tvName.setText(booking.getPhotographer_name());
                tvAddress.setText(booking.getAddress_name());
                tvPrice.setText(StringUtil.getPriceVNDCurrency(booking.getPrice()));
                tvDate.setText(Constant.BOOK_DATE_TIME_FORMAT.format(booking.getStart_time()));
                tvTime.setText(StringUtil.getTimeCreated(itemView.getContext(), booking.getCreate_time().getTime()));
                if (booking.getRating_star() > 0) {
                    tvStar.setRating(booking.getRating_star());
                    tvStar.setVisibility(View.VISIBLE);
                } else tvStar.setVisibility(View.GONE);
                BookStatus bookStatus = booking.getStatus();
                tvStatus.setBackgroundResource(bookStatus.getBackground());
                tvStatus.setText(bookStatus.getText());
                if (booking.getPhotographer_id().equals(PrefUtil.getUid())) {
                    itemView.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View v) {
                            if (mBookClickListener != null) mBookClickListener.onEdit(booking);
                        }
                    });
                } else {
                    if (bookStatus == BookStatus.OPENED) {
                        itemView.setOnClickListener(new View.OnClickListener() {
                            @Override
                            public void onClick(View v) {
                                if (mBookClickListener != null)
                                    mBookClickListener.onAttend(booking);
                            }
                        });
                    } else
                        itemView.setOnClickListener(null);
                }

                if (bookStatus == BookStatus.OPENED || bookStatus == BookStatus.CLOSED && booking.isHasAttends()) {
                    if (booking.getPhotographers_attended() == null || booking.getPhotographers_attended().isEmpty()) {
                        recyclerView.setVisibility(View.GONE);
                        FirebaseHelper.getListAttend(booking, new FirebaseHelper.GetListAttendListener() {
                            @Override
                            public void getListAttened(ArrayList<User> users) {
                                if (users != null) {
                                    booking.setPhotographers_attended(users);
                                    mListBooking.set(pos, booking);
                                    notifyDataSetChanged();
                                }
                            }
                        });
                    } else {
                        recyclerView.setVisibility(View.VISIBLE);
                        mUserAdapter.setUsers(booking.getPhotographers_attended());
                    }
                } else recyclerView.setVisibility(View.GONE);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    public interface OnItemBookClickListener {
        void onEdit(Booking booking);

        void onAttend(Booking booking);
    }
}
