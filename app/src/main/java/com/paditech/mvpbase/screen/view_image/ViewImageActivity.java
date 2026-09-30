package com.paditech.mvpbase.screen.view_image;

import android.app.AlertDialog;
import android.content.DialogInterface;
import android.view.View;
import android.widget.ImageView;
import android.widget.RatingBar;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenter;
import com.paditech.mvpbase.common.mvp.activity.MVPActivity;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.common.utils.ImageUtil;

import butterknife.BindView;
import butterknife.OnClick;

/**
 * Created by ThanhNgocHoang on 11/8/2017.
 */

public class ViewImageActivity extends MVPActivity<ViewImageContact.PresenterViewOps> implements ViewImageContact.ViewOps {

    @BindView(R.id.tv_name)
    TextView tvName;
    @BindView(R.id.tv_count)
    TextView tvCount;
    @BindView(R.id.tv_time)
    TextView tvTime;
    @BindView(R.id.image)
    ImageView imageView;

    private String mImageUrl;

    @Override
    protected int getContentView() {
        return R.layout.frag_image_view;
    }

    @Override
    protected void initView() {
        if(getIntent().getExtras() != null) {
            mImageUrl = getIntent().getStringExtra("image_url");
        }
        if (mImageUrl != null)
            ImageUtil.loadImage(getActivityContext(), mImageUrl, imageView);
    }


    @Override
    protected Class<? extends ActivityPresenter> onRegisterPresenter() {
        return ViewImagePresenter.class;
    }

    @OnClick({R.id.btn_star, R.id.btn_edit, R.id.btn_share, R.id.btn_info})
    public void onViewClicked(View view) {
        switch (view.getId()) {
            case R.id.btn_star:
                showRatingStar();
                break;
            case R.id.btn_edit:
                showToast("ahuhu");
                break;
            case R.id.btn_share:
                break;
            case R.id.btn_info:
                break;
        }
    }

    private void showRatingStar() {
        final AlertDialog.Builder popDialog  = new AlertDialog.Builder(getActivity());
        final RatingBar rating = new RatingBar(getActivity());
        rating.setMax(5);
        rating.setNumStars(5);


       // JSONObject js = new JSONObject();
        rating.setRating((float)4.5);
        popDialog .setTitle("Vote!");
        popDialog .setView(rating);

        //Buttton
        popDialog.setPositiveButton(android.R.string.ok,
                new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                    // to do somthing save when click okie
                        showToast(String.valueOf(rating.getProgress()));
                       
                    }
                })
                .setNegativeButton("Cancel",
                        new DialogInterface.OnClickListener() {
                            @Override
                            public void onClick(DialogInterface dialog, int which) {
                                dialog.cancel();
                            }
                        });

        popDialog .create();
        popDialog .show();

    }
}
